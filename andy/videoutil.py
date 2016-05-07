import atexit
import locale
import pathlib
import shutil
import sqlite3
import subprocess
import os
import json
from collections import deque
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
    def __init__(self, database=None, dboptional=True):
        self.colors=Color()
        self.util=Util()
        self.program=Program()
        if database:
            try:
                self.database=sqlite3.connect(database)
            except (sqlite3.OperationalError, TypeError):
                if dboptional:
                    self.database=None
                    self.db=None
                    print("{} Could not open database or no database specified.".format(self.colors.mood("neutral")))
                    pass
                else:
                    raise
            else:
                atexit.register(self.database.close)
                self.db=self.database.cursor()

        self.mkvpropedit=shutil.which("mkvpropedit", mode=os.X_OK)
        self.ffmpeg=shutil.which("ffmpeg", mode=os.X_OK)
        self.mkvmerge=shutil.which("mkvmerge", mode=os.X_OK)
        self.ffprobe=shutil.which("ffprobe", mode=os.X_OK)

class ABS(VideoUtil):
    def __init__(self, database=str(pathlib.Path.cwd().joinpath("videoinfo.sqlite")), debug=None, backup=None, output=None, converttest=False):
        VideoUtil.__init__(database=database)

        self.debug=debug

        if backup:
            self.backuppath=pathlib.Path(backup).resolve()
            self.backup=str(self.backuppath)
        else:
            self.backuppath=None
            self.backup=None

        if output:
            self.outputpath=pathlib.Path(output).resolve()
        else:
            self.outputpath=pathlib.Path.cwd()

        self.output=str(self.outputpath)

        self.converttest=converttest

        self.auto=False
        self.fr=False

        self.nocodec=(None, "none", "copy")

        if not self.ffmpeg:
            print("{} ffmpeg not found, exiting.")
            raise FileNotFoundError

    def convert(self, filename, videocodec=None, videobitrate=None, audiocodec=None, audiobitrate=None, videocodecopts=None, audiocodecopts=None, audiofilteropts=None, container=None, framerate=None, passes=2):

        filepath=pathlib.Path(filename).resolve()
        outpath=self.outputpath.joinpath(filepath.with_suffix(container).name)
        output=str(outpath)
        def frameratefilter():
            if framerate:
                return ["-filter:v", "fps={}".format(framerate)]
            elif self.database and not framerate and videocodec not in self.nocodec:
                if self.fr is False:
                    print("{} Frame Rate not specified, attempting to read from the database.".format(self.colors.mood("neutral")))
                    self.frcount=True
                with self.database:
                    try:
                        self.db.execute("select frame_rate from videoinfo where filename=?", (filepath.name,))
                        fr=self.db.fetchone()
                        return ["-filter:v", "fps={}".format(fr[0])]
                    except (sqlite3.Error, IndexError):
                        print("{} Frame Rate for {} not found in database, will rely on ffmpeg auto-detection.".format(self.colors.mood("neutral"), filename))
                        return None
                        pass
            elif not self.database and not framerate:
                print("{} Frame Rate not specified and there is no videoinfo database, will rely on ffmpeg auto-detection.".format(self.colors.mood("neutral")))
                return None

        if videocodec in self.nocodec or not videocodec:
            passes=1


        def commandlist(passno=None, passmax=passes):
            if passno is None and passmax is 2:
                print("{} You must specify a pass number if using 2-pass encoding.".format(self.colors.mood("sad")))
                raise ValueError

            if passmax not in (1, 2):
                print("{} The maximum pass variable can only be 1 or 2.".format(self.colors.mood("sad")))
                raise ValueError

            if isinstance(passno, int) and (passno >=2 and passmax is 1):
                print("{} is >=2 and the maximum number of passes is set to 1.".format(self.colors.mood("sad")))
                raise ValueError

            def auto_bitrates():
                if self.database:
                    if self.auto is False:
                        print("{} Bit-rates not specified, attempting to guess from database entries.".format(self.colors.mood("neutral")))
                        self.auto=True
                    with self.database:
                        self.db.execute("select streams from videoinfo where filename=?", (filepath.name,))
                        streams=self.db.fetchone()[0]
                        self.db.execute("select bitrate_0_raw, bitrate_1_raw from videoinfo where filename=?", (filepath.name,))
                        bitrates=self.db.fetchone()
                        if streams is 2:
                            return [bitrates[0], bitrates[1]]
                        elif streams is 1:
                            return bitrates
                else:
                    return None
            if ('videobitrate' not in vars() and 'audiobitrate' not in vars()) or (not videobitrate and not audiobitrate):
                bitrates=auto_bitrates()
                """print(bitrates)"""
                """if len(bitrates) is not 2:
                    print("{} Bitrates variable must have 2 entries.".format(self.colors.mood("sad")))
                    raise ValueError"""
                if self.debug:
                    print(bitrates)

            if (not 'videobitrate' in vars() or not videobitrate) and videocodec not in self.nocodec and len(bitrates) is 2:
                videobitrate=str(max(bitrates))
                if self.debug:
                    print(videobitrate)
            elif not 'videobitrate' in vars() and videocodec not in self.nocodec and (not 'audiocodec' in vars() or not audiocodec) and len(bitrates) is 1:
                videobitrate=str(bitrates)
                if self.debug:
                    print(videobitrate)

            if not 'audiobitrate' in vars() and audiocodec not in self.nocodec and len(bitrates) is 2:
                audiobitrate=str(min(bitrates))
                if self.debug:
                    print(audiobitrate)
            elif not 'audiobitrate' in vars() and audiocodec not in self.nocodec and len(bitrates) is 1:
                audiobitrate=str(bitrates)
                if self.debug:
                    print(audiobitrate)

            biglist=[]
            baselist=[self.ffmpeg, "-i", str(filepath)]
            videocodeclist=["-c:v", videocodec]
            bitratelist=["-b:v", videobitrate]
            passlist=["-pass", str(passno), "-passlogfile", str(filepath.with_suffix(""))]
            listsuffix=["-hide_banner", "-y"]

            biglist.append(baselist)

            if videocodec not in self.nocodec:
                biglist.append(videocodeclist)
                fr=frameratefilter()
                if fr:
                    biglist.append(fr)
                biglist.append(bitratelist)

            if passmax is 2:
                biglist.append(passlist)

            if videocodecopts:
                biglist.append(videocodecopts)

            if passno is 1:
                biglist.append(["-an", listsuffix, "-f", "matroska", "/dev/null"])
            else:
                if audiocodec not in (None, "none"):
                    biglist.append(["-c:a", audiocodec])
                    if audiocodec is not "copy":
                        biglist.append(["-b:a", audiobitrate])
                        if audiocodecopts:
                            biglist.append(audiocodecopts)
                        if audiofilteropts:
                            biglist.append(["-af", audiofilteropts])
                else:
                    biglist.append("-an")
                biglist.append([listsuffix, output])

            #print(list(flatten(biglist))) #temporary for debugging purposes

            return list(self.util.flatten(biglist))

        def convertdone():
            if self.database and not self.converttest:
                with self.database:
                    print("{} Removing {} from the database".format(self.colors.mood("happy"), filepath.name))
                    self.db.execute('delete from videoinfo where filename = ?', (filepath.name,))
            if self.backuppath and self.backuppath.exists():
                print("{} Moving {} to {}".format(self.colors.mood("happy"), filepath.name, self.backup))
                shutil.move(str(filepath), self.backup)

            if ("mkv" in container or "mka" in container) and self.mkvpropedit:
                print("{} Adding statistics tags to output file.".format(self.colors.mood("happy")))
                self.program.runprogram([self.mkvpropedit, "--add-track-statistics-tags", output])

        if self.debug:
            print('')
            if passes is 2:
                print(commandlist(passno=1, passmax=2))
                print(commandlist(passno=2, passmax=2))
            else:
                print(commandlist(passmax=1))

        if passes is 2 and not self.debug:
            try:
                self.program.runprogram(commandlist(passno=1, passmax=2))
                self.program.runprogram(commandlist(passno=2, passmax=2))
            except (KeyboardInterrupt, subprocess.CalledProcessError):
                if outpath.exists():
                    print("\n{} Removing unfinished file.".format(self.colors.mood("neutral")))
                    outpath.unlink()
            else:
                convertdone()
            finally:
                if pathlib.Path(filename.replace(filepath.suffix, "-0.log")).exists():
                    print("{} Removing 1st pass log file.".format(self.colors.mood("neutral")))
                    self.program.runprogram(["rm", filename.replace(filepath.suffix, "-0.log")])

        elif passes is 1 and not self.debug:
            try:
                self.program.runprogram(commandlist(passmax=1))
            except (KeyboardInterrupt, subprocess.CalledProcessError):
                if outpath.exists():
                    print("{} Removing unfinished file.".format(self.colors.mood("neutral")))
                    outpath.unlink()
            else:
                convertdone()

class VideoInfo(VideoUtil):
    def __init__(self, dbfile=None):
        if dbfile:
            VideoUtil.__init__(database=dbfile, dboptional=False)
        else:
            VideoUtil.__init__()
        self.createstatement='CREATE TABLE IF NOT EXISTS videoinfo (id integer primary key, filename text unique, duration text, duration_raw real, streams integer, bitrate_total text, bitrate_0 text, bitrate_1 text, bitrate_0_raw integer, bitrate_1_raw integer, codec_0 text, codec_1 text, container text, width integer, height integer, frame_rate real, hash text unique)'
        self.createstatementjson='CREATE TABLE IF NOT EXISTS videojson (id INTEGER UNIQUE, filename TEXT UNIQUE, jsondata JSON)'

    def resetjson(self, dbfile=None):
        if self.database:
            with self.database:
                print("{} Purging JSON cache from {}".format(self.colors.mood("happy"), pathlib.Path(databasefile).resolve()))
                self.db.execute('delete from videojson')
        else:
            database=sqlite3.connect(dbfile)
            with database:
                db=database.cursor()
                print("{} Purging JSON cache from {}".format(self.colors.mood("happy"), pathlib.Path(databasefile).resolve()))
                db.execute('delete from videojson')

    def resetvideoinfo(self, dbfile=None):
        if self.database:
            with self.database:
                print("{} Regenerating the videoinfo table for {}.".format(self.colors.mood("happy"), pathlib.Path(databasefile).resolve()))
                self.db.execute('drop table if exists videoinfo')
                self.db.execute(self.createstatement)
        else:
            database=sqlite3.connect(dbfile)
        with database:
            print("{} Regenerating the videoinfo table for {}.".format(self.colors.mood("happy"), pathlib.Path(databasefile).resolve()))

    def deleteentry(self, table, criteria, value, dbfile=None):
        if self.database:
            with self.database:
                print("{} Deleting {} from {}".format(self.colors.mood("happy"), value, table))
                self.db.execute('delete from ? where ?=?', (table, criteria, value))
        else:
            database=sqlite3.connect(dbfile)
            with database:
                db=database.cursor()
                db.execute('delete from ? where ?=?', (table, criteria, value))

class GenVideoInfo(VideoUtil, VideoInfo):
    def __init__(self, databasefile=str(pathlib.Path.cwd().joinpath("videoinfo.sqlite")), delete=False, debug=False):
        # VideoUtil.__init__(database=databasefile, dboptional=False)
        VideoInfo.__init__(dbfile=databasefile)
        self.debug=debug
        self.delete=delete
        self.reset_json=reset_json
        self.filehash={}

    def genhashlist(self, files, existinghash=None):
        for filename in files:
            if filename not in existinghash:
                print("{} Calculating hash for {}".format(self.colors.mood("happy"), filename))
                yield filename, hashfile(filename)

    def genexisting(self):
        with self.database:
            self.db.execute("select filename, hash from videoinfo")
            for filename, hashval in self.db.fetchall():
                yield filename, hashval

    def genfilelist(self, filelist=None, existinghash=None):
        try:
            whitelist = ["video/x-flv", "video/mp4", "video/mp2t", "video/3gpp", "video/quicktime", "video/x-msvideo", "video/x-ms-wmv", "video/webm", "video/x-matroska", "video/msvideo", "video/avi", "application/vnd.rm-realmedia", "audio/x-pn-realaudio", "audio/x-matroska", "audio/ogg", "video/ogg", "audio/vorbis", "video/theora", "video/3gpp2", "audio/x-wav", "audio/wave", "video/dvd", "video/mpeg", "application/vnd.rn-realmedia-vbr", "audio/vnd.rn-realaudio", "audio/x-realaudio"]

            with magic.Magic(flags=magic.MAGIC_MIME_TYPE) as m:
                if filelist:
                    if isinstance(filelist, str) and pathlib.Path(filelist).is_dir():
                        paths=pathlib.Path(filelist).iterdir()
                        for filepath in paths:
                            if not self.debug:
                                if m.id_filename(filepath.name) in whitelist and filepath.is_file() and filepath.name not in existinghash:
                                    yield str(filepath)
                            else:
                                if m.id_filename(filepath.name) in whitelist and filepath.is_file():
                                    yield str(filepath)
                    else:
                        for filename in filelist:
                            filepath=pathlib.Path(filename)
                            if not self.debug:
                                if m.id_filename(filename) in whitelist and filepath.is_file() and filepath.name not in existinghash:
                                    yield filepath.name
                            else:
                                if m.id_filename(filename) in whitelist and filepath.is_file():
                                    yield filepath.name
                else:
                    for filepath in pathlib.Path.cwd().iterdir():
                        if not self.debug:
                            if m.id_filename(str(filepath)) in whitelist and filepath.is_file() and filepath.name not in existinghash:
                                yield filepath.name
                        else:
                            if m.id_filename(str(filepath)) in whitelist and filepath.is_file():
                                yield filepath.name
        except NameError:
            whitelist = ['.webm', '.mkv', '.flv', '.vob', '.ogg', '.drc', '.avi', '.wmv', '.yuv', '.rm', '.rmvb', '.asf', '.mp4', '.m4v', '.mpg', '.mp2', '.mpeg', '.mpe', '.mpv', '.3gp', '.3g2', '.mxf', '.roq', '.nsv', '.f4v', '.wav', '.ra', '.mka']
            if filelist:
                if isinstance(filelist, str) and pathlib.Path(filelist).is_dir():
                    paths=pathlib.Path(filelist).iterdir()
                    for filepath in paths:
                        if not self.debug:
                            if filepath.suffix in whitelist and filepath.is_file() and filepath.name not in existinghash:
                                yield str(filepath)
                        else:
                            if filepath.suffix in whitelist and filepath.is_file():
                                yield str(filepath)

                for filename in filelist:
                    filepath=pathlib.Path(filename)
                    if not self.debug:
                        if filepath.suffix in whitelist and filepath.is_file() and filepath.name not in existinghash:
                            yield str(filepath)
                    else:
                        if filepath.suffix in whitelist and filepath.is_file():
                            yield str(filepath)
            else:
                for filepath in pathlib.Path.cwd().iterdir():
                    if not self.debug:
                        if filepath.suffix in whitelist and filepath.is_file() and filepath.name not in existinghash:
                            yield str(filepath)
                    else:
                        if filepath.suffix in whitelist and filepath.is_file():
                            yield str(filepath)
            pass

    def gvigenjson(self, videofile):
        with self.database:
            self.db.execute('select filename from videojson where filename = ?', (videofile,))
            try:
                entryexists=self.db.fetchone()[0]
            except (TypeError, IndexError, KeyError):
                entryexists=False
                pass
            if entryexists:
                self.db.execute('select jsondata from videojson where filename = ?', (videofile,))
                if self.debug:
                    print("{} Using Database".format(self.colors.mood("neutral")))
                return self.db.fetchone()[0]
            else:
                if self.debug:
                    print("Extracting Data")
                return self.program.returninfo(["ffprobe", "-i", videofile, "-hide_banner", "-of", "json", "-show_streams", "-show_format"], string=True)

    def generate(self, videofile, hash=self.filehash):
        print("{} Extracting metadata for {}".format(self.colors.mood("happy"), videofile))
        video_dict={}
        jsondata=json.loads(GenVideoInfo.gvigenjson(videofile))

        video_dict["filename"]=pathlib.Path(videofile).name
        video_dict["duration"]=time.strftime("%H:%M:%S", time.gmtime(int(float(jsondata["format"].get("duration")))))
        video_dict["duration_raw"]=float(jsondata["format"].get("duration"))
        video_dict["bitrate_total"]=naturalsize(jsondata["format"].get("bit_rate")).replace(" MB", "M").replace(" kB", "K")
        video_dict["container"]=jsondata["format"].get("format_name")
        video_dict["streams"]=jsondata["format"].get("nb_streams")
        try:
            if "tags" in jsondata["streams"][0] and not "bit_rate" in jsondata["streams"][0] and "BPS" in jsondata["streams"][0]["tags"]:
                video_dict["bitrate_0"]=naturalsize(jsondata["streams"][0]["tags"].get("BPS")).replace(" MB", "M").replace(" kB", "K")
            else:
                video_dict["bitrate_0"]=naturalsize(jsondata["streams"][0].get("bit_rate")).replace(" MB", "M").replace(" kB", "K")
        except (KeyError, IndexError, TypeError):
            video_dict["bitrate_0"]=None
            pass
        try:
            if "tags" in jsondata["streams"][0] and not "bit_rate" in jsondata["streams"][0] and "BPS" in jsondata["streams"][0]["tags"]:
                video_dict["bitrate_0_raw"]=int(jsondata["streams"][0]["tags"].get("BPS"))
            else:
                video_dict["bitrate_0_raw"]=int(jsondata["streams"][0].get("bit_rate"))
        except (KeyError, IndexError, TypeError):
            video_dict["bitrate_0_raw"]=None
            pass

        try:
            if "tags" in jsondata["streams"][1] and not "bitrate" in jsondata["streams"][1] and "BPS" in jsondata["streams"][1]["tags"]:
                video_dict["bitrate_1"]=naturalsize(jsondata["streams"][1]["tags"].get("BPS")).replace(" MB", "M").replace(" kB", "K")
            else:
                video_dict["bitrate_1"]=naturalsize(jsondata["streams"][1].get("bit_rate")).replace(" MB", "M").replace(" kB", "K")
        except (KeyError, IndexError, TypeError):
            video_dict["bitrate_1"]=None
            pass
        try:
            if "tags" in jsondata["streams"][1] and not "bitrate" in jsondata["streams"][1] and "BPS" in jsondata["streams"][1]["tags"]:
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

        video_dict["hash"]=hash

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
                if not "frame_rate" in video_dict and not video_dict["frame_rate"]:
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
    def write(self, videodict):
        columns=', '.join(tuple(videodict.keys()))
        placeholders=':'+', :'.join(videodict.keys())
        query='insert into videoinfo ({}) values ({})'.format(columns, placeholders)

        if self.debug:
            print("Dictionary Keys:", tuple(video_dict.keys()))
            print("Dictionary Values:", tuple(video_dict.values()))
            print("Number of keys in Dictionary:", len(video_dict.keys()))
            print("SQL Query:", query)
        else:
            with self.database:
                db=self.database.cursor()
                db.execute(query, video_dict)

                db.execute('select filename from videojson where filename = ?', (video_dict["filename"],))
                try:
                    entryexists=db.fetchone()[0]
                except(TypeError, KeyError, IndexError):
                    entryexists=False
                    pass
                if not entryexists:
                    print("{} Caching a copy of the json data for {}".format(self.colors.mood("happy"), video_dict["filename"]))
                    db.execute('select id from videoinfo where filename = ?', (video_dict["filename"],))
                    dbid=db.fetchone()[0]
                    db.execute('insert into videojson values(?, ?, ?)', (dbid, video_dict["filename"], json.dumps(jsondata)))

class FindVideoInfo(VideoUtil):
    def __init__(self, directory):
        VideoUtil.__init__()
        try:
            test=magic.Magic()
        except NameError:
            print("{} Filemagic module not installed.".format(self.colors.mood("sad")))
            raise
        else:
            del test

        if isinstance(directory, (list, tuple, deque)):
            self.paths=[]
            for d in directory:
                self.paths.append(pathlib.Path(d).rglob("videoinfo.sqlite"))
        else:
            self.paths=pathlib.Path(directory).rglob("videoinfo.sqlite")

    def find(self):
        for filename in self.paths:
            with magic.Magic() as m, open(str(filename), "rb") as f:
                filetype=m.id_buffer(f.read())
                if "SQLite 3.x database" in filetype:
                    yield str(filename.parent)

class ResetVideoInfo(VideoUtil, FindVideoInfo, GenVideoInfo, VideoInfo):
    def __init__(self, directory, reset_json=False, reset_videoinfo=True):
        VideoUtil.__init__()
        self.fvi=FindVideoInfo(directory)
        self.gvi=GenVideoInfo()

        self.directories=Util.sortentries(list(self.fvi.find()))

        self.reset_json=reset_json
        self.reset_videoinfo=reset_videoinfo

    def reset(self):
        newline=False

        for directory in self.directories:
            dbpath=pathlib.Path(directory).joinpath("videoinfo.sqlite")
            vi=VideoInfo(vidatabase=str(dbpath))
            gvi=GenVideoInfo(databasefile=str(dbpath))
            if dbpath.exists():
                database=sqlite3.connect(str(dbpath))
            else:
                continue
            if newline:
                print('')
            if newline is False:
                newline=True
            print("{} Resetting videoinfo database in {}".format(self.colors.mood("happy"), directory))

            with database:
                if self.reset_json:
                    self.db.execute('delete from videojson')
                if self.reset_videoinfo:
                    self.db.execute('drop table videoinfo')
            for files in GenVideoInfo.genfilelist(filelist=directory):
