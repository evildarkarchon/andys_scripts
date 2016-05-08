import atexit
import locale
import pathlib
import shutil
import sqlite3
import subprocess
import os
import json
import time
import sys
import tempfile

from humanize.filesize import naturalsize

try:
    import magic
except ImportError:
    pass

from andy.util import Color, Util, Program

locale.setlocale(locale.LC_ALL, "en_US.utf-8")

class VideoUtil:
    def __init__(self):
        self.mkvpropedit=shutil.which("mkvpropedit", mode=os.X_OK)
        self.ffmpeg=shutil.which("ffmpeg", mode=os.X_OK)
        self.mkvmerge=shutil.which("mkvmerge", mode=os.X_OK)
        self.ffprobe=shutil.which("ffprobe", mode=os.X_OK)

class VideoInfo:
    def __init__(self, dbfile):
        self.colors=Color()
        self.util=Util()
        self.program=Program()
        self.database=sqlite3.connect(dbfile)
        global aereg
        if 'aereg' not in vars():
            aereg=False
        if aereg is False:
            atexit.register(self.database.close)
            aereg=True

        self.db=self.database.cursor()
        self.createstatement='CREATE TABLE IF NOT EXISTS videoinfo (id integer primary key, filename text unique, duration text, duration_raw real, streams integer, bitrate_total text, bitrate_0 text, bitrate_1 text, bitrate_0_raw integer, bitrate_1_raw integer, codec_0 text, codec_1 text, container text, width integer, height integer, frame_rate real, hash text unique)'
        self.createstatementjson='CREATE TABLE IF NOT EXISTS videojson (id INTEGER PRIMARY KEY, filename TEXT UNIQUE, jsondata JSON)'
        self.dbfile=dbfile
        self.ffprobe=shutil.which("ffprobe", mode=os.X_OK)

    def createvideoinfo(self):
        with self.database:
            self.db.execute(self.createstatement)

    def createvideojson(self):
        with self.database:
            self.execute(self.createstatementjson)

    def resetjson(self):
        with self.database:
            print("{} Purging JSON cache from {}".format(self.colors.mood("happy"), self.dbfile))
            self.db.execute('drop table if exists videojson')
            self.db.execute(self.createstatementjson)
            self.db.execute('vacuum')

    def resetvideoinfo(self):
        with self.database:
            print("{} Regenerating the videoinfo table for {}.".format(self.colors.mood("happy"), self.dbfile))
            self.db.execute('drop table if exists videoinfo')
            self.db.execute(self.createstatement)
            self.db.execute('vacuum')

    def deleteentry(self, value):
        with self.database:
            print("{} Deleting {} from videoinfo".format(self.colors.mood("happy"), value))
            self.db.execute('delete from videoinfo where filename=?', (value,))
            self.db.execute('vacuum')

    def maintainence(self):
        with self.database:
            print("{} Vacuuming Database.")
            self.db.execute('vacuum')

    def queryvideoinfomr(self, query, *values):
        with self.database:
            self.db.execute(query, values)
            return self.db.fetchall()

    def queryvideoinfosr(self, query, *values):
        with self.database:
            self.db.execute(query, values)
            return self.db.fetchone()

    def execviquery(self, query, *values):
        with self.database:
            self.db.execute(query, values)
    def execviquerynp(self, query, dictionary):
        with self.database:
            self.db.execute(query, dictionary)

class GenVideoInfo(VideoInfo):
    def __init__(self, databasefile, debug=False):
        VideoInfo.__init__(self, databasefile)
        self.vi=VideoInfo(databasefile)
        self.debug=debug

        av=self.vi.queryvideoinfosr('pragma auto_vacuum')
        if av[0] is not 1:
            self.vi.execviquery('pragma auto_vacuum = 1')
            self.db.execute('vacuum')

        pgsize=self.vi.queryvideoinfosr('pragma page_size')
        if pgsize[0] is not 4096:
            self.vi.execviquery('pragma page_size = 4096')
            self.vi.execviquery('vacuum')
        cachesize=self.vi.queryvideoinfosr('pragma cache_size')
        if cachesize[0] is not -2000:
            self.vi.execviquery('pragma cache_size = -2000')


        vit=self.vi.queryvideoinfosr("SELECT name FROM sqlite_master WHERE type='table' AND name='videoinfo';")
        try:
            vitemp=len(vit)
        except TypeError:
            self.vi.execviquery(self.createstatement)
            pass
        else:
            del vitemp

        vj=self.vi.queryvideoinfosr("SELECT name FROM sqlite_master WHERE type='table' AND name='videojson';")
        try:
            vjtemp=len(vj)
        except TypeError:
            self.vi.execviquery(self.createstatementjson)
        else:
            del vjtemp

    def genhashlist(self, files, existinghash=None):
        for filename in files:
            if existinghash:
                if filename not in existinghash:
                    print("{} Calculating hash for {}".format(self.colors.mood("happy"), pathlib.Path(filename).name))
                    yield filename, self.util.hashfile(filename)
            else:
                print("{} Calculating hash for {}".format(self.colors.mood("happy"), pathlib.Path(filename).name))
                yield filename, self.util.hashfile(filename)

    def genexisting(self):
        for filename, hashval in self.vi.queryvideoinfomr("select filename, hash from videoinfo"):
            yield filename, hashval

    def genfilelist(self, filelist, existinghash=None):
        try:
            whitelist = ["video/x-flv", "video/mp4", "video/mp2t", "video/3gpp", "video/quicktime", "video/x-msvideo", "video/x-ms-wmv", "video/webm", "video/x-matroska", "video/msvideo", "video/avi", "application/vnd.rm-realmedia", "audio/x-pn-realaudio", "audio/x-matroska", "audio/ogg", "video/ogg", "audio/vorbis", "video/theora", "video/3gpp2", "audio/x-wav", "audio/wave", "video/dvd", "video/mpeg", "application/vnd.rn-realmedia-vbr", "audio/vnd.rn-realaudio", "audio/x-realaudio"]

            with magic.Magic(flags=magic.MAGIC_MIME_TYPE) as m:
                for filename in filelist:
                    if pathlib.Path(filename).is_dir():
                        paths=pathlib.Path(filename).iterdir()
                        for filepath in paths:
                            if not self.debug and existinghash:
                                if m.id_filename(filepath.name) in whitelist and filepath.is_file() and filepath.name not in existinghash:
                                    yield str(filepath)
                            elif self.debug or not existinghash:
                                if m.id_filename(filepath.name) in whitelist and filepath.is_file():
                                    yield str(filepath)
                    else:
                        filepath=pathlib.Path(filename)
                        if not self.debug and existinghash:
                            if m.id_filename(filename) in whitelist and filepath.is_file() and filepath.name not in existinghash:
                                yield str(filepath)
                        elif self.debug or not existinghash:
                            if m.id_filename(filename) in whitelist and filepath.is_file():
                                yield str(filepath)
        except NameError:
            whitelist = ['.webm', '.mkv', '.flv', '.vob', '.ogg', '.drc', '.avi', '.wmv', '.yuv', '.rm', '.rmvb', '.asf', '.mp4', '.m4v', '.mpg', '.mp2', '.mpeg', '.mpe', '.mpv', '.3gp', '.3g2', '.mxf', '.roq', '.nsv', '.f4v', '.wav', '.ra', '.mka']
            for filename in filelist:
                if pathlib.Path(filelist).is_dir():
                    paths=pathlib.Path(filelist).iterdir()
                    for filepath in paths:
                        if not self.debug and existinghash:
                            if filepath.suffix in whitelist and filepath.is_file() and filepath.name not in existinghash:
                                yield str(filepath)
                        elif self.debug or not existinghash:
                            if filepath.suffix in whitelist and filepath.is_file():
                                yield str(filepath)
                else:
                    filepath=pathlib.Path(filename)
                    if not self.debug and existinghash:
                        if filepath.suffix in whitelist and filepath.is_file() and filepath.name not in existinghash:
                            yield str(filepath)
                    elif self.debug or not existinghash:
                        if filepath.suffix in whitelist and filepath.is_file():
                            yield str(filepath)
            pass

    def gvigenjson(self, videofile):
        print("{} Extracting metadata for {}".format(self.colors.mood("happy"), pathlib.Path(videofile).name))
        try:
            entryexists=self.vi.queryvideoinfosr('select filename from videojson where filename = ?', videofile)[0]
        except (TypeError, IndexError, KeyError):
            entryexists=False
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
        video_dict={}
        jsondata=json.loads(jsoninfo)

        video_dict["filename"]=pathlib.Path(videofile).name
        video_dict["duration"]=time.strftime("%H:%M:%S", time.gmtime(int(float(jsondata["format"].get("duration")))))
        video_dict["duration_raw"]=float(jsondata["format"].get("duration"))
        video_dict["bitrate_total"]=naturalsize(jsondata["format"].get("bit_rate")).replace(" MB", "M").replace(" kB", "K")
        video_dict["container"]=jsondata["format"].get("format_name")
        video_dict["streams"]=jsondata["format"].get("nb_streams")
        try:
            if "tags" in jsondata["streams"][0] and "bit_rate" not in jsondata["streams"][0] and "BPS" in jsondata["streams"][0]["tags"]:
                video_dict["bitrate_0"]=naturalsize(jsondata["streams"][0]["tags"].get("BPS")).replace(" MB", "M").replace(" kB", "K")
            else:
                video_dict["bitrate_0"]=naturalsize(jsondata["streams"][0].get("bit_rate")).replace(" MB", "M").replace(" kB", "K")
        except (KeyError, IndexError, TypeError):
            video_dict["bitrate_0"]=None
            pass
        try:
            if "tags" in jsondata["streams"][0] and "bit_rate" not in jsondata["streams"][0] and "BPS" in jsondata["streams"][0]["tags"]:
                video_dict["bitrate_0_raw"]=int(jsondata["streams"][0]["tags"].get("BPS"))
            else:
                video_dict["bitrate_0_raw"]=int(jsondata["streams"][0].get("bit_rate"))
        except (KeyError, IndexError, TypeError):
            video_dict["bitrate_0_raw"]=None
            pass

        try:
            if "tags" in jsondata["streams"][1] and "bitrate" not in jsondata["streams"][1] and "BPS" in jsondata["streams"][1]["tags"]:
                video_dict["bitrate_1"]=naturalsize(jsondata["streams"][1]["tags"].get("BPS")).replace(" MB", "M").replace(" kB", "K")
            else:
                video_dict["bitrate_1"]=naturalsize(jsondata["streams"][1].get("bit_rate")).replace(" MB", "M").replace(" kB", "K")
        except (KeyError, IndexError, TypeError):
            video_dict["bitrate_1"]=None
            pass
        try:
            if "tags" in jsondata["streams"][1] and "bitrate" not in jsondata["streams"][1] and "BPS" in jsondata["streams"][1]["tags"]:
                video_dict["bitrate_1_raw"]=int(jsondata["streams"][1]["tags"].get("BPS"))
            else:
                video_dict["bitrate_1_raw"]=int(jsondata["streams"][1].get("bit_rate"))
        except (KeyError, IndexError, TypeError):
            video_dict["bitrate_1_raw"]=None
            pass

        try:
            video_dict["height"]=jsondata["streams"][0].get("height")
        except (KeyError, IndexError):
            video_dict["height"]=None
            pass

        try:
            video_dict["width"]=jsondata["streams"][0].get("width")
        except (KeyError, IndexError):
            video_dict["width"]=None
            pass

        video_dict["codec_0"]=jsondata["streams"][0].get("codec_name")

        try:
            video_dict["codec_1"]=jsondata["streams"][1].get("codec_name")
        except (KeyError, IndexError):
            video_dict["codec_1"]=None
            pass

        if not video_dict["height"]:
            try:
                video_dict["height"]=jsondata["streams"][1].get("height")
            except (KeyError, IndexError):
                video_dict["height"]=None
                pass
        if not video_dict["width"]:
            try:
                video_dict["width"]=jsondata["streams"][1].get("width")
            except (KeyError, IndexError):
                video_dict["width"]=None
                pass

        video_dict["hash"]=filehash

        if jsondata["streams"][0].get("avg_frame_rate"):
            try:
                framerate=round(eval(jsondata["streams"][0].get("avg_frame_rate")), 2)
                if framerate is not 0 and isinstance(framerate, (int, float)):
                    video_dict["frame_rate"]=framerate
                else:
                    video_dict["frame_rate"]=None
            except ZeroDivisionError:
                video_dict["frame_rate"]=None
                pass
        elif jsondata["streams"][1].get("avg_frame_rate"):
            try:
                framerate=round(eval(jsondata["streams"][1].get("avg_frame_rate")), 2)
                if "frame_rate" not in video_dict and not video_dict["frame_rate"]:
                    if framerate is not 0 and isinstance(framerate, (int, float)):
                        video_dict["frame_rate"]=framerate
                    else:
                        video_dict["frame_rate"]=None
            except ZeroDivisionError:
                video_dict["frame_rate"]=None
                pass
        else:
            video_dict["frame_rate"]=None
        return video_dict

    def write(self, videodict, jsondata):
        columns=', '.join(tuple(videodict.keys()))
        placeholders=':' + ', :'.join(videodict.keys())
        viquery='insert into videoinfo ({}) values ({})'.format(columns, placeholders)
        jsoninfo=json.loads(jsondata)
        jsoninfo["format"]["filename"]=videodict["filename"]

        if self.debug:
            print("Dictionary Keys:", tuple(videodict.keys()))
            print("Dictionary Values:", tuple(videodict.values()))
            print("Number of keys in Dictionary:", len(videodict.keys()))
            print("SQL Query:", viquery)
        else:
            self.vi.execviquerynp(viquery, videodict)

            try:
                entryexists=self.vi.queryvideoinfosr('select filename from videojson where filename = ?', videodict["filename"])[0]
            except (TypeError, KeyError, IndexError):
                entryexists=False
                pass
            if not entryexists:
                print("{} Caching a copy of the json data for {}".format(self.colors.mood("happy"), videodict["filename"]))
                self.vi.execviquery('insert into videojson (filename, jsondata) values(?, ?)', videodict["filename"], json.dumps(jsoninfo))

class FindVideoInfo:
    def __init__(self):
        try:
            test=magic.Magic()
        except NameError:
            print("{} Filemagic module not installed.".format(self.colors.mood("sad")))
            raise
        else:
            del test

    def find(self, directory="/data/Private"):
        paths=pathlib.Path(directory).rglob("videoinfo.sqlite")
        for filename in paths:
            with magic.Magic() as m, open(str(filename), "rb") as f:
                filetype=m.id_buffer(f.read())
                if "SQLite 3.x database" in filetype:
                    yield str(filename.parent)
