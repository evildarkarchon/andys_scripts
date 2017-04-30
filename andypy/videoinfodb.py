# pylint: disable=r0903, c0301, c0111, r0912, r0915, c0411
import collections  # noqa: F401  # pylint: disable=W0611
import concurrent.futures  # noqa: F401  # pylint: disable=W0611
import json
import pathlib
import time
from contextlib import contextmanager

# from sqlalchemy.schema import Table
import sqlalchemy.orm.exc
from humanize.filesize import naturalsize
from sqlalchemy import (Column, Float, Integer,  # pylint: disable=c0412
                        String, create_engine)
from sqlalchemy.engine.reflection import Inspector
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker  # relationship would go here.

from .mood2 import Mood
from .string_eval import NumericStringParser
from .util.hashfile import hashfile  # noqa: F401  # pylint: disable=W0611
from .videoinfo.probe import probe

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


class Info:

    def __init__(self, filename, jsondata, filehash):
        if not isinstance(jsondata, dict):
            jsondata = json.loads(jsondata)

        self.filename = pathlib.Path(filename).name
        self.hash = filehash
        self.container = jsondata["format"]["format_name"]
        self.duration = time.strftime("%H:%M:%S", time.gmtime(int(float(jsondata["format"]["duration"]))))
        self.duration_raw = jsondata["format"]["duration"]
        self.numstreams = int(jsondata["format"]["nb_streams"])
        self.codec_0 = jsondata["streams"][0]["codec_name"]
        self.type_0 = jsondata["streams"][0]["codec_type"]
        if isinstance(jsondata["streams"][1], dict) and jsondata["streams"][1]["codec_name"]:
            self.codec_1 = jsondata["streams"][1]["codec_name"]
        else:
            self.codec_1 = None

        if isinstance(jsondata["streams"][1], dict) and jsondata["streams"][1]["codec_type"]:
            self.type_1 = jsondata["streams"][1]["codec_type"]
        else:
            self.type_1 = None

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
        self.bitrate_0 = bitrate(0)
        self.bitrate_1 = bitrate(1)
        self.bitrate_total = naturalsize(jsondata["format"]["bit_rate"]).replace(" MB", "Mbps").replace(" kB", "Kbps")

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

        self.bitrate_0_raw = bitrate_raw(0)
        self.bitrate_1_raw = bitrate_raw(1)

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
        self.height = height()
        self.width = width()
        self.frame_rate = frame_rate()
        self.jsondata = json.dumps(jsondata)

    def __repr__(self):
        out = "<Info(filename={}, hash={}, container={}, duration={}, ".format(self.filename, self.hash, self.container, self.duration)
        out += "duration_raw={}, numstreams={}, codec_0={}, ".format(self.duration_raw, self.numstreams, self.codec_0)
        out += "type_0={}, bitrate_0={}, codec_1={}, ".format(self.type_0, self.bitrate_0, self.codec_1)
        out += "type_1={}, bitrate_1={}, bitrate_total={}, ".format(self.type_1, self.bitrate_1, self.bitrate_total)
        out += "height={}, width={}, frame_rate={}, jsondata={})>".format(self.height, self.width, self.frame_rate, self.jsondata)

        return out


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
        out = "<VideoInfo(filename={}, duration={}, duration_raw={}, ".format(self.filename, self.duration, self.duration_raw)
        out += "numstreams={}, container={}, width={}, height={}, ".format(self.numstreams, self.container, self.width, self.height)
        out += "frame_rate={}, bitrate_total={}, bitrate_0={}, ".format(self.frame_rate, self.bitrate_total, self.bitrate_0)
        out += "bitrate_0_raw={}, type_0={}, codec_0={}, ".format(self.bitrate_0_raw, self.type_0, self.codec_0)
        out += "bitrate_1={}, bitrate_1_raw={}, type_1={}, ".format(self.bitrate_1, self.bitrate_1_raw, self.type_1)
        out += "codec_1={}, filehash={})>".format(self.codec_1, self.filehash)
        return out


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
            print(Mood.happy("Deleting existing videoinfo table."))
            VideoInfo.__table__.drop(self.dataengine)  # pylint: disable=e1101
            if regenjson:
                print(Mood.happy("Deleting existing videojson table."))
                VideoJSON.__table__.drop(self.dataengine)   # pylint: disable=e1101
        print(Mood.happy("Creating database tables."))
        SQLBase.metadata.create_all(self.dataengine)
        if verbose:
            print(Mood.happy("Tables List:\n{}".format(self.inspect.get_table_names())))
            if "videoinfo" in self.inspect.get_table_names():
                print(Mood.happy("Column Names:\n{}".format(self.inspect.get_columns("videoinfo"))))
        sessionbase = sessionmaker(bind=self.dataengine)
        self.session = sessionbase()  # pylint: disable=c0103

    def parse(self, videofile, ffprobe=None, bequiet=False):
        cache = None
        videoname = str(pathlib.Path(videofile).name)
        try:
            cache = self.session.query(VideoJSON).filter(VideoJSON.filename == videoname).one()
            print(Mood.happy("Information found in the cache."))
            # print(cache.json)
        except sqlalchemy.orm.exc.NoResultFound:
            # if self.verbose:
            #    print("{} No entry in the cache.".format(Mood.neutral()))
            print(Mood.neutral("No entry in the cache."))

        if isinstance(cache, VideoJSON):
            return cache.json
        else:
            return probe(videofile, ffprobe, bequiet)

    @classmethod
    def cwd(cls, verbosemode=False, regen=False, regenjson=False):  # pylint: disable=W0221
        """Class method to simplify and prettify accessing a videoinfo database in the current directory with the name "videoinfo.sqlite".

        verbosemode takes a True or False and passes it along to the parent class."""
        if not pathlib.Path.cwd().joinpath("videoinfo.sqlite").exists():  # pylint: disable=e1101
            pathlib.Path.cwd().joinpath("videoinfo.sqlite").touch()  # pylint: disable=e1101
        return cls(str(pathlib.Path.cwd().joinpath("videoinfo.sqlite")), verbosemode, regen, regenjson)

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
            yield None


class FindVideoInfo:  # pylint: disable=R0903

    """This class contains any functions related to locating videoinfo databases.
    Requires filemagic, python-magic will not work, if python-magic is installed, get rid of it and use filemagic instead.
    It's not easy to test for which is which as they use the same module name."""

    @staticmethod
    def find(directory="/data/Private"):
        """Worker function that locates directories with videoinfo database that are under the specified directory.
        Files will be run through filemagic to verify that they actually sqlite databases.
        Just like the genfilelist function in GenVideoInfo, this only works with filemagic,
        if python-magic is installed, get rid of it and use filemagic instead. Its not easy to distinguish
        python-magic from filemagic as they use the same module name.

        directory is the directory to be searched."""

        try:
            test = magic.Magic()
        except NameError:
            print(Mood.sad("Filemagic module not installed."))
            raise
        else:
            del test

        paths = pathlib.Path(directory).rglob("videoinfo.sqlite")
        for filename in paths:
            with magic.Magic() as m, open(str(filename), "rb") as f:
                filetype = m.id_buffer(f.read())
                if "SQLite 3.x database" in filetype:
                    yield str(filename.parent)
