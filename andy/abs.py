import atexit
import locale
import pathlib
import shutil
import sqlite3
import subprocess
from collections import deque

from andy.colors import Color
from andy.flatten import flatten
from andy.runprogram import runprogram

colors=Color()

locale.setlocale(locale.LC_ALL, "en_US.utf-8")

class ABS:
    def __init__(self, database=pathlib.Path(str(pathlib.Path.cwd()), "videoinfo.sqlite"), debug=None, backup=None, output=None, converttest=False):
        try:
            self.database=sqlite3.connect(database)
        except (sqlite3.OperationalError, TypeError):
            self.database=None
            self.db=None
            print("{} Could not open database or no database specified.".format(colors.mood("neutral")))
            pass
        else:
            atexit.register(self.database.close)
            self.db=self.database.cursor()
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

    def convert(self, filename, videocodec=None, videobitrate=None, audiocodec=None, audiobitrate=None, videocodecopts=None, audiocodecopts=None, audiofilteropts=None, container=None, framerate=None, passes=2):

        filepath=pathlib.Path(filename).resolve()
        outpath=self.outputpath.joinpath(filepath.with_suffix(container).name)
        def frameratefilter():
            if framerate:
                return ["-filter:v", "fps={}".format(framerate)]
            elif self.database and not framerate and videocodec not in (None,"none","copy"):
                print("{} Frame Rate not specified, attempting to read from the database.".format(colors.mood("neutral")))
                with self.database:
                    try:
                        self.db.execute("select frame_rate from videoinfo where filename=?", (filepath.name,))
                        fr=self.db.fetchone()
                        return ["-filter:v", "fps={}".format(fr[0])]
                    except (sqlite3.Error, IndexError):
                        print("{} Frame Rate for {} not found in database, will rely on ffmpeg auto-detection.".format(colors.mood("neutral"), filename))
                        return None
                        pass
            elif not self.database and not framerate:
                print("{} Frame Rate not specified and there is no videoinfo database, will rely on ffmpeg auto-detection.".format(colors.mood("neutral")))
                return None

        if videocodec in ("copy", "none") or not videocodec:
            passes=1

        def commandlist(passno=None, passmax=passes):
            if passno is None and passmax is 2:
                print("{} You must specify a pass number if using 2-pass encoding.".format(colors.mood("sad")))
                raise ValueError

            if passmax not in (1, 2):
                print("{} The maximum pass variable can only be 1 or 2.".format(colors.mood("sad")))
                raise ValueError

            if isinstance(passno, int) and (passno >=2 and passmax is 1):
                print("{} is >=2 and the maximum number of passes is set to 1.".format(colors.mood("sad")))
                raise ValueError

            def auto_bitrates():
                if self.database:
                    with self.database:
                        self.db.execute("select bitrate_0_raw, bitrate_1_raw from videoinfo where filename=?", (filepath.name,))
                        bitrates=self.db.fetchone()
                    #print(bitrates[0][1])
                        return [bitrates[0], bitrates[1]]
                else:
                    return None
            if ('videobitrate' not in vars() and 'audiobitrate' not in vars()) or (not videobitrate and not audiobitrate):
                bitrates=auto_bitrates()
                if len(bitrates) is not 2):
                    print("{} Bitrates variable must have 2 entries.".format(colors.mood("sad")))
                    raise ValueError
                if self.debug:
                    print(bitrates)

            if not 'videobitrate' in vars() and videocodec not in (None, "none", "copy") and bitrates and len(bitrates) is 2:
                videobitrate=str(max(bitrates))
                if self.debug:
                    print(videobitrate)

            if not 'audiobitrate' in vars() and audiocodec not in (None, "none", "copy") and bitrates and len(bitrates) is 2:
                audiobitrate=str(min(bitrates))
                if self.debug:
                    print(audiobitrate)

            if 'audiobitrate' in vars() and audiocodec not in (None, "none", "copy"):
                if not len(audiobitrate) >= 1:
                    print("{} Audio bitrate variable can not be empty if assigned.".format(colors.mood("sad")))
                    raise ValueError
            if 'videobitrate' in vars() and videocodec not in (None, "none", "copy"):
                if not len(videobitrate) >= 1):
                    print("{} Video bitrate variable can not be empty if assigned.".format(colors.mood("sad")))
                    raise ValueError

            biglist=[]
            baselist=["ffmpeg", "-i", str(filepath)]
            videocodeclist=["-c:v", videocodec]
            bitratelist=["-b:v", videobitrate]
            passlist=["-pass", str(passno), "-passlogfile", str(filepath.with_suffix(""))]
            listsuffix=["-hide_banner", "-y"]

            biglist.append(baselist)

            if videocodec not in (None, "none", "copy"):
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
                biglist.append([listsuffix, str(outpath)])

            #print(list(flatten(biglist))) #temporary for debugging purposes

            return list(flatten(biglist))

        if self.debug:
            print('')
            if passes is 2:
                print(commandlist(passno=1, passmax=2))
                print(commandlist(passno=2, passmax=2))
            else:
                print(commandlist(passmax=1))

        if passes is 2 and not self.debug:
            try:
                runprogram(commandlist(passno=1, passmax=2))
                runprogram(commandlist(passno=2, passmax=2))
            except (KeyboardInterrupt, subprocess.CalledProcessError):
                if outpath.exists():
                    print("\n{} Removing unfinished file.".format(colors.mood("neutral")))
                    outpath.unlink()
            else:
                if self.database and not self.converttest:
                    with self.database:
                        print("{} Removing {} from the database".format(colors.mood("happy"), filepath.name))
                        self.db.execute('delete from videoinfo where filename = ?', (filepath.name,))
                if self.backuppath and self.backuppath.exists():
                    print("{} Moving {} to {}".format(colors.mood("happy"), filepath.name, self.backup))
                    shutil.move(str(filepath), self.backup)
            finally:
                if pathlib.Path(filename.replace(filepath.suffix, "-0.log")).exists():
                    print("{} Removing 1st pass log file.".format(colors.mood("neutral")))
                    runprogram(["rm", filename.replace(filepath.suffix, "-0.log")])

        elif passes is 1 and not self.debug:
            try:
                runprogram(commandlist(passmax=1))
            except (KeyboardInterrupt, subprocess.CalledProcessError):
                if outpath.exists():
                    print("\n{} Removing unfinished file.".format(colors.mood("neutral")))
                    outpath.unlink()
            else:
                if self.database and not self.converttest:
                    with self.database:
                        #db=self.database.cursor()
                        print("{} Removing {} from the database".format(colors.mood("happy"), filepath.name))
                        self.db.execute('delete from videoinfo where filename = ?', (filepath.name,))
                if self.backuppath and self.backuppath.exists():
                    print("{} Moving {} to {}".format(colors.mood("happy"), filepath.name, self.backup))
                    shutil.move(str(filepath), self.backup)
