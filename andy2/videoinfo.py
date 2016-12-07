# pylint: disable=r0903, c0301, c0111, r0912, r0915, c0411
import collections  # noqa: F401  # pylint: disable=W0611
import concurrent.futures  # noqa: F401  # pylint: disable=W0611
import json
import os
import pathlib
import shutil
import time
from contextlib import contextmanager

from humanize.filesize import naturalsize
from sqlalchemy import Column, Float, Integer, String, create_engine  # ForeignKey would go here.
from sqlalchemy.engine.reflection import Inspector
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker  # relationship would go here.
# from sqlalchemy.schema import Table
import sqlalchemy.orm.exc
from andy2.string_eval import NumericStringParser

try:
    from util import Mood, Program, Util  # noqa: F401  # pylint: disable=W0611
except ImportError:
    from andy.util import Mood, Program, Util  # noqa: F401  # pylint: disable=W0611

try:
    # This must be the filemagic module, the python-magic plugin (which uses the same module name) will most likely not work.
    import magic  # noqa: F401  # pylint: disable=W0611
except ImportError:
    pass


@contextmanager
def sqa_session(basesess):
    try:
        yield basesess
        basesess.commit()
    except:
        basesess.rollback()
        raise
    finally:
        basesess.close()


SQLBase = declarative_base()  # pylint: disable=c0103


class VideoInfo(SQLBase):
    __tablename__ = 'videoinfo'
    id = Column(Integer, primary_key=True)  # pylint: disable=c0103
    filename = Column(String, nullable=False, unique=True)
    duration = Column(String)
    duration_raw = Column(Float)
    numstreams = Column(Integer)
    container = Column(String, nullable=False)
    width = Column(Integer)
    height = Column(Integer)
    frame_rate = Column(Float)
    bitrate_total = Column(String)
    bitrate_0 = Column(String)
    bitrate_0_raw = Column(Integer)
    type_0 = Column(String)
    codec_0 = Column(String)
    bitrate_1 = Column(String)
    bitrate_1_raw = Column(Integer)
    type_1 = Column(String)
    codec_1 = Column(String)
    filehash = Column(String, unique=True, nullable=False)

    def __repr__(self):
        return "<VideoInfo(filename={}, duration={}, duration_raw={}, numstreams={}, container={}, width={}, height={}, frame_rate={}, bitrate_total={}, bitrate_0={}, bitrate_0_raw={}, type_0={}, codec_0={}, bitrate_1={}, bitrate_1_raw={}, type_1={}, codec_1={}, filehash={})>".format(self.filename, self.duration, self.duration_raw, self.numstreams, self.container, self.width, self.height, self.frame_rate, self.bitrate_total, self.bitrate_0, self.bitrate_0_raw, self.type_0, self.codec_0, self.bitrate_1, self.bitrate_1_raw, self.type_1, self.codec_1, self.filehash)


class VideoJSON(SQLBase):
    __tablename__ = 'videojson'
    id = Column(Integer, primary_key=True)
    filename = Column(String, nullable=False, unique=True)
    json = Column(String, nullable=False, unique=True)

    def __repr__(self):
        return "<VideoJSON(filename={}, json={})>".format(self.filename, self.json)


class VideoData:
    def __init__(self, db, verbose=False, regen=False, regenjson=False):
        if not pathlib.Path(db).exists():
            pathlib.Path(db).touch()

        self.dbpath = pathlib.Path(db).resolve()
        self.verbose = verbose
        self.dataengine = create_engine("sqlite:///{}".format(self.dbpath))
        self.inspect = Inspector.from_engine(self.dataengine)
        if regen:
            # with self.dataengine.connect() as con:
            #    print("{} Deleting existing videoinfo table.".format(Mood.happy()))
            #    con.execute("DROP TABLE videoinfo")
            #    if regenjson:
            #        print("{} Deleting existing videojson table.".format(Mood.happy()))
            #        con.execute("DROP TABLE videojson")
            #    con.execute('VACUUM')
            print("{} Deleting existing videoinfo table.".format(Mood.happy()))
            VideoInfo.__table__.drop(self.dataengine)  # pylint: disable=e1101
            if regenjson:
                print("{} Deleting existing videojson table.".format(Mood.happy()))
                VideoJSON.__table__.drop(self.dataengine)   # pylint: disable=e1101
        print("{} Creating database tables.".format(Mood.happy()))
        SQLBase.metadata.create_all(self.dataengine)
        if verbose:
            print("{} Tables List:\n{}".format(Mood.happy(), self.inspect.get_table_names()))
            if "videoinfo" in self.inspect.get_table_names():
                print("{} Column Names:\n{}".format(Mood.happy(), self.inspect.get_columns("videoinfo")))
        sessionbase = sessionmaker(bind=self.dataengine)
        self.session = sessionbase()  # pylint: disable=c0103

    def parse(self, videofile, probe=None, quiet=False):
        cache = None
        try:
            cache = self.session.query(VideoJSON).filter(VideoJSON.filename == videofile).one()
            print("{} Information found in the cache.".format(Mood.happy()))
            # print(cache.json)
        except sqlalchemy.orm.exc.NoResultFound:
            # if self.verbose:
            #    print("{} No entry in the cache.".format(Mood.neutral()))
            print("{} No entry in the cache.".format(Mood.neutral()))

        if isinstance(cache, VideoJSON):
            return cache.json
        else:
            ffprobe = None
            if probe:
                ok = os.access(probe, mode=os.X_OK, effective_ids=True)  # pylint: disable=c0103
                if ok:
                    ffprobe = probe
                    del probe
                    del ok
                else:
                    raise FileNotFoundError("Specified ffprobe compatible command not found or not executable by current user.")
            else:
                ffprobe = shutil.which("ffprobe", mode=os.X_OK)

            if not ffprobe:
                raise FileNotFoundError("Could not find ffprobe.")
            if not quiet:
                print("{} Extracting information from {}".format(Mood.happy(), videofile))
            return json.loads(Program.returninfo([ffprobe, "-i", videofile, "-hide_banner", "-of", "json", "-show_streams", "-show_format"], string=True))

    @staticmethod
    def probe(videofile, prog=None, quiet=False):
        """Alternate version of the parse method that does not use the database.

        videofile is the file to probe.

        prog is the program to use to do the probing. If none is specified, ffprobe shall be searched for and used."""

        ffprobe = None
        if prog:
            ok = os.access(prog, mode=os.X_OK, effective_ids=True)  # pylint: disable=c0103
            if ok:
                ffprobe = prog
                del prog
                del ok
            else:
                raise FileNotFoundError("Specified ffprobe compatible command not found or not executable by current user.")
        else:
            ffprobe = shutil.which("ffprobe", mode=os.X_OK)

        if not ffprobe:
            raise FileNotFoundError("Could not find ffprobe.")
        if not quiet:
            print("{} Extracting information from {}".format(Mood.happy(), videofile))
        return json.loads(Program.returninfo([ffprobe, "-i", videofile, "-hide_banner", "-of", "json", "-show_streams", "-show_format"], string=True))

    @classmethod
    def cwd(cls, verbosemode=False, regen=False, regenjson=False):  # pylint: disable=W0221
        """Class method to simplify and prettify accessing a videoinfo database in the current directory with the name "videoinfo.sqlite".

        verbosemode takes a True or False and passes it along to the parent class."""
        if not pathlib.Path.cwd().joinpath("videoinfo.sqlite").exists():  # pylint: disable=e1101
            pathlib.Path.cwd().joinpath("videoinfo.sqlite").touch()  # pylint: disable=e1101
        return cls(str(pathlib.Path.cwd().joinpath("videoinfo.sqlite")), verbosemode, regen, regenjson)

    @staticmethod
    def gendict(filename, jsondata, filehash):
        if not isinstance(jsondata, dict):
            jsondata = json.loads(jsondata)

        yield "filename", pathlib.Path(filename).name
        yield "hash", filehash
        yield "container", jsondata["format"]["format_name"]
        yield "duration", time.strftime("%H:%M:%S", time.gmtime(int(float(jsondata["format"]["duration"]))))
        yield "duration_raw", jsondata["format"]["duration"]
        yield "numstreams", int(jsondata["format"]["nb_streams"])
        yield "codec_0", jsondata["streams"][0]["codec_name"]
        yield "type_0", jsondata["streams"][0]["codec_type"]
        if isinstance(jsondata["streams"][1], dict) and jsondata["streams"][1]["codec_name"]:
            yield "codec_1", jsondata["streams"][1]["codec_name"]
        else:
            yield "codec_1", None

        if isinstance(jsondata["streams"][1], dict) and jsondata["streams"][1]["codec_type"]:
            yield "type_1", jsondata["streams"][1]["codec_type"]
        else:
            yield "type_1", None

        def bitrate(stream):
            if not isinstance(stream, int):
                raise TypeError("Argument must be an integer.")
            try:
                if isinstance(jsondata["streams"][stream], dict):
                    if "tags" in jsondata["streams"][stream] and "bit_rate" not in jsondata["streams"][stream] and "BPS" in jsondata["streams"][stream]["tags"]:
                        return naturalsize(jsondata["streams"][stream]["tags"]["BPS"]).replace(" MB", "Mbps").replace(" kB", "Kbps")
                    elif "bit_rate" in jsondata["streams"][stream]:
                        return naturalsize(jsondata["streams"][stream]["bit_rate"]).replace(" MB", "Mbps").replace(" kB", "Kbps")
                    else:
                        return None
            except (KeyError, IndexError):
                return None
        yield "bitrate_0", bitrate(0)
        yield "bitrate_1", bitrate(1)
        yield "bitrate_total", naturalsize(jsondata["format"]["bit_rate"]).replace(" MB", "Mbps").replace(" kB", "Kbps")

        def bitrate_raw(stream):
            if not isinstance(stream, int):
                raise TypeError("Argument must be an integer.")

            try:
                if isinstance(jsondata["streams"][stream], dict):
                    if "tags" in jsondata["streams"][stream] and "bit_rate" not in jsondata["streams"][stream] and "BPS" in jsondata["streams"][stream]["tags"]:
                        return int(jsondata["streams"][stream]["tags"]["BPS"])
                    elif "bit_rate" in jsondata["streams"][stream]:
                        return int(jsondata["streams"][stream]["bit_rate"])
                    else:
                        return None
            except (KeyError, IndexError):
                return None

        yield "bitrate_0_raw", bitrate_raw(0)
        yield "bitrate_1_raw", bitrate_raw(1)

        def height():
            try:
                if jsondata["streams"][0]["codec_type"] == "video" and jsondata["streams"][0]["height"]:
                    return jsondata["streams"][0]["height"]
                elif isinstance(jsondata["streams"][1], dict) and jsondata["streams"][1]["codec_type"] == "video" and jsondata["streams"][0]["height"]:
                    return jsondata["streams"][1]["height"]
                else:
                    return None
            except (KeyError, IndexError):
                return None

        def width():
            try:
                if jsondata["streams"][0]["codec_type"] == "video" and jsondata["streams"][0]["width"]:
                    return jsondata["streams"][0]["width"]
                elif isinstance(jsondata["streams"][1], dict) and jsondata["streams"][1]["codec_type"] == "video" and jsondata["streams"][1]["width"]:
                    return jsondata["streams"][1]["width"]
            except (KeyError, IndexError):
                return None

        def frame_rate():
            try:
                nsp = NumericStringParser()
                if jsondata["streams"][0]["codec_type"] == "video" and jsondata["streams"][0]["avg_frame_rate"]:
                    return "{0:.2f}".format(float(nsp.eval(jsondata["streams"][0]["avg_frame_rate"])))
                elif isinstance(jsondata["streams"][1], dict) and jsondata["streams"][1]["codec_type"] == "video" and jsondata["streams"][1]["avg_frame_rate"]:
                    return "{0:.2f}".format(float(nsp.eval(jsondata["streams"][1]["avg_frame_rate"])))
                else:
                    return None
            except (KeyError, IndexError):
                return None
        yield "height", height()
        yield "width", width()
        yield "frame_rate", frame_rate()
        yield "jsondata", json.dumps(jsondata)

    def genexisting(self):
        """Generator function that queries an existing videoinfo database and yields the filename and hash for any existing files in the database."""
        if self.session.query(VideoInfo).count() >= 1:
            out = self.session.query(VideoInfo).all()
            # print(out)
            for i in out:
                # print(i.filename)
                # print(i.filehash)
                yield i.filename, i.filehash
        else:
            return None

    def genfilelist(self, filelist, existinghash=None):
        """Generator function that takes a list of files and yields a filtered list that eliminates any non-video files (based on known mime types or file extensions) and any files that are already in the database.
        It will use the filemagic module if available for matching based on mime type or use a file extension whitelist if filemagic is not detected.
        python-magic WILL NOT WORK and there is no easy way to test for it as it uses the same module name.
        So if python-magic is installed, get rid of it and install filemagic instead."""

        try:
            whitelist = ['video/x-flv', 'video/mp4', 'video/mp2t', 'video/3gpp', 'video/quicktime', 'video/x-msvideo', 'video/x-ms-wmv', 'video/webm', 'video/x-matroska', 'video/msvideo', 'video/avi', 'application/vnd.rm-realmedia', 'audio/x-pn-realaudio', 'audio/x-matroska', 'audio/ogg', 'video/ogg', 'audio/vorbis', 'video/theora', 'video/3gpp2', 'audio/x-wav', 'audio/wave', 'video/dvd', 'video/mpeg', 'application/vnd.rn-realmedia-vbr', 'audio/vnd.rn-realaudio', 'audio/x-realaudio']

            with magic.Magic(flags=magic.MAGIC_MIME_TYPE) as m:
                for filename in filelist:
                    filepath = pathlib.Path(filename)
                    if not self.verbose and existinghash:
                        if m.id_filename(filename) in whitelist and filepath.is_file() and filepath.name not in existinghash:
                            yield str(filepath)
                    elif self.verbose or not existinghash:
                        if m.id_filename(filename) in whitelist and filepath.is_file():
                            yield str(filepath)
        except NameError:
            whitelist = ['.webm', '.mkv', '.flv', '.vob', '.ogg', '.drc', '.avi', '.wmv', '.yuv', '.rm', '.rmvb', '.asf', '.mp4', '.m4v', '.mpg', '.mp2', '.mpeg', '.mpe', '.mpv', '.3gp', '.3g2', '.mxf', '.roq', '.nsv', '.f4v', '.wav', '.ra', '.mka']
            for filename in filelist:
                filepath = pathlib.Path(filename)
                if not self.verbose and existinghash:
                    if filepath.suffix in whitelist and filepath.is_file() and filepath.name not in existinghash:
                        yield str(filepath)
                elif self.verbose or not existinghash:
                    if filepath.suffix in whitelist and filepath.is_file():
                        yield str(filepath)

    @staticmethod
    def genhashlist(files, existinghash=None):
        """Generator function that takes a list of files and a list of existing hashes (if any) and calculates hashes for those files.

        files takes a list containing file names for which hashes will be calculated.

        existinghash takes a dictionary where the filename is the key and the hash is the value, this is optional."""

        for filename in files:
            if existinghash and filename not in existinghash:
                print("{} Calculating hash for {}".format(Mood.happy(), pathlib.Path(filename).name))
                yield filename, Util.hashfile(filename)
            else:
                print("{} Calculating hash for {}".format(Mood.happy(), pathlib.Path(filename).name))
                yield filename, Util.hashfile(filename)


class FindVideoInfo:  # pylint: disable=R0903

    """This class contains any functions related to locating videoinfo databases.
    Requires filemagic, python-magic will not work, if python-magic is installed, get rid of it and use filemagic instead.
    It's not easy to test for which is which as they use the same module name."""

    def __init__(self):
        try:
            test = magic.Magic()
        except NameError:
            print("{} Filemagic module not installed.".format(Mood.sad()))
            raise
        else:
            del test

    @staticmethod
    def find(directory="/data/Private"):
        """Worker function that locates directories with videoinfo database that are under the specified directory.
        Files will be run through filemagic to verify that they actually sqlite databases.
        Just like the genfilelist function in GenVideoInfo, this only works with filemagic,
        if python-magic is installed, get rid of it and use filemagic instead. Its not easy to distinguish
        python-magic from filemagic as they use the same module name.

        directory is the directory to be searched."""

        paths = pathlib.Path(directory).rglob("videoinfo.sqlite")
        for filename in paths:
            with magic.Magic() as m, open(str(filename), "rb") as f:
                filetype = m.id_buffer(f.read())
                if "SQLite 3.x database" in filetype:
                    yield str(filename.parent)
