import atexit
import locale
import pathlib
import shutil
import sqlite3
import os
import json
import time

from humanize.filesize import naturalsize

try:
    import magic
except ImportError:
    pass

from andy.util import Color, Util, Program

locale.setlocale(locale.LC_ALL, "en_US.utf-8")


class VideoInfo:

    """High-level functions for working with a videoinfo database."""

    def __init__(self, dbfile):
        self.colors = Color()
        self.util = Util()
        self.program = Program()
        self.database = sqlite3.connect(dbfile)
        global aereg
        if 'aereg' not in vars():
            aereg = False
        if aereg is False:
            atexit.register(self.database.close)
            aereg = True

        self.db = self.database.cursor()
        self.createstatement = 'CREATE TABLE IF NOT EXISTS videoinfo (id integer primary key, filename text unique, duration text, duration_raw real, streams integer, bitrate_total text, bitrate_0 text, bitrate_1 text, bitrate_0_raw integer, bitrate_1_raw integer, codec_0 text, codec_1 text, container text, width integer, height integer, frame_rate real, hash text unique)'
        self.createstatementjson = 'CREATE TABLE IF NOT EXISTS videojson (id INTEGER PRIMARY KEY, filename TEXT UNIQUE, jsondata JSON)'
        self.dbfile = dbfile
        self.ffprobe = shutil.which("ffprobe", mode=os.X_OK)

    def createvideoinfo(self):
    
        """Creates the videoinfo table in the videoinfo database."""
    
        with self.database:
            self.db.execute(self.createstatement)

    def createvideojson(self):
    
        """Creates the JSON cache table in the videoinfo database."""
    
        with self.database:
            self.execute(self.createstatementjson)

    def resetjson(self):
    
        """Purges the JSON cache and performs a vacuum operation."""

        with self.database:
            print("{} Purging JSON cache from {}".format(self.colors.mood("happy"), self.dbfile))
            self.db.execute('drop table if exists videojson')
            self.db.execute(self.createstatementjson)
            self.db.execute('vacuum')

    def resetvideoinfo(self):
    
        """Deletes and remakes the videoinfo table and performs a vacuum operation."""
    
        with self.database:
            print("{} Regenerating the videoinfo table for {}.".format(self.colors.mood("happy"), self.dbfile))
            self.db.execute('drop table if exists videoinfo')
            self.db.execute(self.createstatement)
            self.db.execute('vacuum')

    def deleteentry(self, criteria, value):
    
        """Deletes a row or rows from a videoinfo database based on specified criteria (only one criteria is supported).
        A vacuum operation is performed after the query is executed.
        
        criteria is the column or other criteria to be used as the criteria for the query.
        
        value is the value of the criteria to evaluate."""
    
        with self.database:
            print("{} Deleting {} from videoinfo".format(self.colors.mood("happy"), value))
            self.db.execute('delete from videoinfo where ? = ?', (criteria, value))
            self.db.execute('vacuum')

    def deletefileentry(self, value):
    
        """Deletes an entry from the database based on file name.
        A vacuum operation is performed after query execution.
        
        value is the file name of the entry to be deleted."""
    
        with self.database:
            print("{} Deleting {} from videoinfo".format(self.colors.mood("happy"), value))
            self.db.execute('delete from videoinfo where filename = ?', (value,))
            self.db.execute('vacuum')

    def maintainence(self):
    
        """Performs a vacuum operation on the database."""
    
        with self.database:
            print("{} Vacuuming Database.")
            self.db.execute('vacuum')

    def queryvideoinfomr(self, query, *values):
    
        """Performs a query on the videoinfo database, It will only accept select or pragma queries as there is a separate set of functions for executing queries that don't expect a result.
        This function is for returning multiple results.
        
        query is the sql query to be executed (using normal placeholders).
        
        values takes multiple positional arguments that will be turned into a tuple to fill in the placeholders
        in the query."""
    
        if "select" not in query and "pragma" not in query and "SELECT" not in query and "PRAGMA" not in query:
            print("{} Query is not a SELECT or PRAGMA query, use execviquery or execviquerynp instead.")
            raise ValueError
        with self.database:
            self.db.execute(query, values)
            return self.db.fetchall()

    def queryvideoinfosr(self, query, *values):
    
        """Performs a query on the videoinfo database, It will only accept select or pragma queries as there is a separate set of functions for executing queries that don't expect a result.
        This function is for returning a single result.
        
        query is the sql query to be executed (using normal placeholders).
        
        values takes multiple positional arguments that will be turned into a tuple to fill in the placeholders
        in the query."""
    
        if "select" not in query and "pragma" not in query and "SELECT" not in query and "PRAGMA" not in query:
            print("{} Query is not a SELECT or PRAGMA query, use execviquery or execviquerynp instead.")
            raise ValueError
        with self.database:
            self.db.execute(query, values)
            return self.db.fetchone()

    def execviquery(self, query, *values):
    
        """Executes an arbitrary query on the videoinfo database. It will not return any results, so use the queryvideoinfo series of functions for that.
        
        query is the sql query to be executed (using normal placeholders).
        
        values takes multiple positional arguments that will be turned into a tuple to fill in the placeholders
        in the query."""
    
        with self.database:
            self.db.execute(query, values)

    def execviquerynp(self, query, dictionary):
        
        """Executes an arbitrary query on the videoinfo database. It will not return any results, so use the queryvideoinfo series of functions for that.
        
        query is the sql query to be executed (using named placeholders).
        
        values takes a dictionary of arguments where the keys correspond to the named placeholders."""
        
        with self.database:
            self.db.execute(query, dictionary)


class GenVideoInfo(VideoInfo):

    """Worker class for generating info to be put in a videoinfo database.
    
    databasefile is the file name of the file to write to.
    
    debug indicates whether to run in debug (aka pretend) mode. In this mode, the sql queries and video info dictionaries are generated,
    but the queries are not actually executed."""


    def __init__(self, databasefile, debug=False):
        VideoInfo.__init__(self, databasefile)
        self.vi = VideoInfo(databasefile)
        self.debug = debug

        av = self.vi.queryvideoinfosr('pragma auto_vacuum')
        if av[0] is not 1:
            self.vi.execviquery('pragma auto_vacuum = 1')
            self.vi.execviquery('vacuum')

        pgsize = self.vi.queryvideoinfosr('pragma page_size')
        if pgsize[0] is not 4096:
            self.vi.execviquery('pragma page_size = 4096')
            self.vi.execviquery('vacuum')
        cachesize = self.vi.queryvideoinfosr('pragma cache_size')
        if cachesize[0] is not -2000:
            self.vi.execviquery('pragma cache_size = -2000')

        vit = self.vi.queryvideoinfosr("SELECT name FROM sqlite_master WHERE type='table' AND name='videoinfo';")
        try:
            vitemp = len(vit)
        except TypeError:
            self.vi.execviquery(self.createstatement)
            pass
        else:
            del vitemp

        vj = self.vi.queryvideoinfosr("SELECT name FROM sqlite_master WHERE type='table' AND name='videojson';")
        try:
            vjtemp = len(vj)
        except TypeError:
            self.vi.execviquery(self.createstatementjson)
        else:
            del vjtemp

    def genhashlist(self, files, existinghash=None):
    
        """Generator function that takes a list of files and a list of existing hashes (if any) and calculates
        hashes for those files.
    
        files takes a list containing file names for which hashes will be calculated.
    
        existinghash takes a dictionary where the filename is the key and the hash is the value, this is optional."""
    
        for filename in files:
            if existinghash and filename not in existinghash:
                print("{} Calculating hash for {}".format(self.colors.mood("happy"), pathlib.Path(filename).name))
                yield filename, self.util.hashfile(filename)
            else:
                print("{} Calculating hash for {}".format(self.colors.mood("happy"), pathlib.Path(filename).name))
                yield filename, self.util.hashfile(filename)

    def genexisting(self):
    
        """Generator function that queries an existing videoinfo database and yields the filename and hash for
        any existing files in the database."""
    
        for filename, hashval in self.vi.queryvideoinfomr("select filename, hash from videoinfo"):
            yield filename, hashval

    def genfilelist(self, filelist, existinghash=None):
    
        """Generator function that takes a list of files and yields a filtered list that eliminates any non-video files (based on known mime types or file extensions) and any files that are already in the database.
        It will use the filemagic module if available for matching based on mime type or use a file extension whitelist if filemagic is not detected.
        python-magic WILL NOT WORK and there is no easy way to test for it as it uses the same module name. 
        So if python-magic is installed, get rid of it and install filemagic instead."""
    
        try:
            whitelist = ["video/x-flv", "video/mp4", "video/mp2t", "video/3gpp", "video/quicktime", "video/x-msvideo", "video/x-ms-wmv", "video/webm", "video/x-matroska", "video/msvideo", "video/avi", "application/vnd.rm-realmedia", "audio/x-pn-realaudio", "audio/x-matroska", "audio/ogg", "video/ogg", "audio/vorbis", "video/theora", "video/3gpp2", "audio/x-wav", "audio/wave", "video/dvd", "video/mpeg", "application/vnd.rn-realmedia-vbr", "audio/vnd.rn-realaudio", "audio/x-realaudio"]

            with magic.Magic(flags=magic.MAGIC_MIME_TYPE) as m:
                for filename in filelist:
                    filepath = pathlib.Path(filename)
                    if not self.debug and existinghash:
                        if m.id_filename(filename) in whitelist and filepath.is_file() and filepath.name not in existinghash:
                            yield str(filepath)
                    elif self.debug or not existinghash:
                        if m.id_filename(filename) in whitelist and filepath.is_file():
                            yield str(filepath)
        except NameError:
            whitelist = ['.webm', '.mkv', '.flv', '.vob', '.ogg', '.drc', '.avi', '.wmv', '.yuv', '.rm', '.rmvb', '.asf', '.mp4', '.m4v', '.mpg', '.mp2', '.mpeg', '.mpe', '.mpv', '.3gp', '.3g2', '.mxf', '.roq', '.nsv', '.f4v', '.wav', '.ra', '.mka']
            for filename in filelist:
                filepath = pathlib.Path(filename)
                if not self.debug and existinghash:
                    if filepath.suffix in whitelist and filepath.is_file() and filepath.name not in existinghash:
                        yield str(filepath)
                elif self.debug or not existinghash:
                    if filepath.suffix in whitelist and filepath.is_file():
                        yield str(filepath)
            pass

    def gvigenjson(self, videofile):
    
        """Worker function that either retrieves the json from the cache or executes ffprobe to generate the json.
        It will then return the json to the caller.
        
        videofile is the video file for which the json will either be queried for or generated."""
    
        print("{} Extracting metadata for {}".format(self.colors.mood("happy"), pathlib.Path(videofile).name))
        try:
            entryexists = self.vi.queryvideoinfosr('select filename from videojson where filename = ?', videofile)[0]
        except (TypeError, IndexError, KeyError):
            entryexists = False
            pass
        if entryexists:
            if self.debug:
                print("{} Using Database".format(self.colors.mood("neutral")))
            return self.vi.queryvideoinfosr('select jsondata from videojson where filename = ?', videofile)[0]
        else:
            if not self.ffprobe:
                print("{} ffprobe not found.".format(self.colors.mood("sad")))
                raise FileNotFoundError
            if self.debug:
                print("{} Extracting Data from file.")
            return self.program.returninfo([self.ffprobe, "-i", videofile, "-hide_banner", "-of", "json", "-show_streams", "-show_format"], string=True)

    def generate(self, videofile, jsoninfo, filehash):
    
        """The workhorse of genvideoinfo, this function generates a dictionary based on json that's either given by gvigenjson or any other source of ffprobe-format json data.
        
        videofile is the file name of the video to extract metadata from.
        
        jsoninfo takes a json string for the json module to load.
        
        filehash takes the hash string for the video file."""
    
        video_dict = {}
        jsondata = json.loads(jsoninfo)

        video_dict["filename"] = pathlib.Path(videofile).name
        video_dict["duration"] = time.strftime("%H:%M:%S", time.gmtime(int(float(jsondata["format"].get("duration")))))
        video_dict["duration_raw"] = float(jsondata["format"].get("duration"))
        video_dict["bitrate_total"] = naturalsize(jsondata["format"].get("bit_rate")).replace(" MB", "M").replace(" kB", "K")
        video_dict["container"] = jsondata["format"].get("format_name")
        video_dict["streams"] = jsondata["format"].get("nb_streams")
        try:
            if "tags" in jsondata["streams"][0] and "bit_rate" not in jsondata["streams"][0] and "BPS" in jsondata["streams"][0]["tags"]:
                video_dict["bitrate_0"] = naturalsize(jsondata["streams"][0]["tags"].get("BPS")).replace(" MB", "M").replace(" kB", "K")
            else:
                video_dict["bitrate_0"] = naturalsize(jsondata["streams"][0].get("bit_rate")).replace(" MB", "M").replace(" kB", "K")
        except (KeyError, IndexError, TypeError):
            video_dict["bitrate_0"] = None
            pass
        try:
            if "tags" in jsondata["streams"][0] and "bit_rate" not in jsondata["streams"][0] and "BPS" in jsondata["streams"][0]["tags"]:
                video_dict["bitrate_0_raw"] = int(jsondata["streams"][0]["tags"].get("BPS"))
            else:
                video_dict["bitrate_0_raw"] = int(jsondata["streams"][0].get("bit_rate"))
        except (KeyError, IndexError, TypeError):
            video_dict["bitrate_0_raw"] = None
            pass

        try:
            if "tags" in jsondata["streams"][1] and "bitrate" not in jsondata["streams"][1] and "BPS" in jsondata["streams"][1]["tags"]:
                video_dict["bitrate_1"] = naturalsize(jsondata["streams"][1]["tags"].get("BPS")).replace(" MB", "M").replace(" kB", "K")
            else:
                video_dict["bitrate_1"] = naturalsize(jsondata["streams"][1].get("bit_rate")).replace(" MB", "M").replace(" kB", "K")
        except (KeyError, IndexError, TypeError):
            video_dict["bitrate_1"] = None
            pass
        try:
            if "tags" in jsondata["streams"][1] and "bitrate" not in jsondata["streams"][1] and "BPS" in jsondata["streams"][1]["tags"]:
                video_dict["bitrate_1_raw"] = int(jsondata["streams"][1]["tags"].get("BPS"))
            else:
                video_dict["bitrate_1_raw"] = int(jsondata["streams"][1].get("bit_rate"))
        except (KeyError, IndexError, TypeError):
            video_dict["bitrate_1_raw"] = None
            pass

        try:
            video_dict["height"] = jsondata["streams"][0].get("height")
        except (KeyError, IndexError):
            video_dict["height"] = None
            pass

        try:
            video_dict["width"] = jsondata["streams"][0].get("width")
        except (KeyError, IndexError):
            video_dict["width"] = None
            pass

        video_dict["codec_0"] = jsondata["streams"][0].get("codec_name")

        try:
            video_dict["codec_1"] = jsondata["streams"][1].get("codec_name")
        except (KeyError, IndexError):
            video_dict["codec_1"] = None
            pass

        if not video_dict["height"]:
            try:
                video_dict["height"] = jsondata["streams"][1].get("height")
            except (KeyError, IndexError):
                video_dict["height"] = None
                pass
        if not video_dict["width"]:
            try:
                video_dict["width"] = jsondata["streams"][1].get("width")
            except (KeyError, IndexError):
                video_dict["width"] = None
                pass

        video_dict["hash"] = filehash

        if jsondata["streams"][0].get("avg_frame_rate"):
            try:
                framerate = round(eval(jsondata["streams"][0].get("avg_frame_rate")), 2)
                if framerate is not 0 and isinstance(framerate, (int, float)):
                    video_dict["frame_rate"] = framerate
                else:
                    video_dict["frame_rate"] = None
            except ZeroDivisionError:
                video_dict["frame_rate"] = None
                pass
        elif jsondata["streams"][1].get("avg_frame_rate"):
            try:
                framerate = round(eval(jsondata["streams"][1].get("avg_frame_rate")), 2)
                if "frame_rate" not in video_dict and not video_dict["frame_rate"]:
                    if framerate is not 0 and isinstance(framerate, (int, float)):
                        video_dict["frame_rate"] = framerate
                    else:
                        video_dict["frame_rate"] = None
            except ZeroDivisionError:
                video_dict["frame_rate"] = None
                pass
        else:
            video_dict["frame_rate"] = None
        return video_dict, jsoninfo

    def write(self, videodict):
    
        """Worker function that does the sql query generation and actually writes the data to the database.
        
        videodict takes a tuple that contains both a videoinfo dictionary and the original json string."""
    
        columns = ', '.join(tuple(videodict[0].keys()))
        placeholders = ':' + ', :'.join(videodict[0].keys())
        viquery = 'insert into videoinfo ({}) values ({})'.format(columns, placeholders)
        jsoninfo = json.loads(videodict[1])
        jsoninfo["format"]["filename"] = videodict[0]["filename"]

        if self.debug:
            print("Dictionary Keys:", tuple(videodict[0].keys()))
            print("Dictionary Values:", tuple(videodict[0].values()))
            print("Number of keys in Dictionary:", len(videodict[0].keys()))
            print("SQL Query:", viquery)
        else:
            self.vi.execviquerynp(viquery, videodict[0])

            try:
                entryexists = self.vi.queryvideoinfosr('select filename from videojson where filename = ?', videodict[0]["filename"])[0]
            except (TypeError, KeyError, IndexError):
                entryexists = False
                pass
            if not entryexists:
                print("{} Caching a copy of the json data for {}".format(self.colors.mood("happy"), videodict[0]["filename"]))
                self.vi.execviquery('insert into videojson (filename, jsondata) values(?, ?)', videodict[0]["filename"], json.dumps(jsoninfo))


class FindVideoInfo:

    """This class contains any functions related to locating videoinfo databases.
    Requires filemagic, python-magic will not work, if python-magic is installed, get rid of it 
    and use filemagic instead. It's not easy to test for which is which as they use the same module name."""


    def __init__(self):
        try:
            test = magic.Magic()
        except NameError:
            print("{} Filemagic module not installed.".format(self.colors.mood("sad")))
            raise
        else:
            del test

    def find(self, directory="/data/Private"):
    
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
