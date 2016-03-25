import sqlite3
import pathlib
import atexit
import subprocess
import shutil

from collections import deque

from andy.runprogram import runprogram
from andy.flatten import flatten
from andy.colors import Color

colors=Color()

class ABS:
    def __init__(self, database=pathlib.Path(str(pathlib.Path.cwd()), "videoinfo.sqlite"), test=None, debug=None, backup=None, output=None):
        try:
            self.database=sqlite3.connect(database)
        except (sqlite3.OperationalError, TypeError):
            self.database=None
            print("{} Could not open database or no database specified.".format(colors.mood("neutral")))
            pass
        else:
            atexit.register(self.database.close)
        self.test=test
        self.debug=debug
        self.db=self.database.cursor()

        if backup:
            self.backuppath=pathlib.Path(backup).resolve()
            self.backup=str(self.backuppath)

        if output:
            self.outputpath=pathlib.Path(output).resolve()
        else:
            self.outputpath=pathlib.Path.cwd()

        self.output=str(self.outputpath)

    def convert(self, filename, videocodec=None, videobitrate=None, audiocodec=None, audiobitrate=None, videocodecopts=None, audiocodecopts=None, audiofilteropts=None, container=None, framerate=None, passes=2):

        filepath=pathlib.Path(filename).resolve()
        outpath=self.outputpath.joinpath(filepath.with_suffix(container).name)

        if self.database and not framerate:
            print("{} Frame Rate not specified, attempting to read from the database.".format(colors.mood("neutral")))
            with self.database:
                try:
                    self.db.execute("select frame_rate from videoinfo where filename=?", (filepath.name,))
                    framerate=self.db.fetchone()
                except sqlite3.Error:
                    print("{} Frame Rate not found in database, will rely on ffmpeg auto-detection.".format(colors.mood("neutral")))
                    framerate=None
                    pass

        if not self.database and not framerate:
            print("{} Frame Rate not specified and there is no videoinfo database, will rely on ffmpeg audto-detection.".format(colors.mood("neutral")))

        if videocodec is "copy" or videocodec is "none" or not videocodec:
            passes=1

        basecommandpass1=deque(["ffmpeg", "-i", str(filepath), "-c:v", videocodec, "-b:v", videobitrate, "-pass", "1", "-passlogfile", str(filepath.with_suffix("")), videocodecopts, "-an", "-hide_banner", "-y", "-f", "matroska", "/dev/null"])
        basecommandpass2=deque(["ffmpeg", "-i", str(filepath), "-c:v", videocodec, "-b:v", videobitrate, "-pass", "2", "-passlogfile", str(filepath.with_suffix("")), videocodecopts, "-c:a", audiocodec, "-b:a", audiobitrate, audiocodecopts, "-af", audiofilteropts, "-hide_banner", "-y", str(outpath)])
        basecommand1pass=deque(["ffmpeg", "-i", str(filepath), "-c:v", videocodec, "-b:v", videobitrate, videocodecopts, "-c:a", audiocodec, "-b:a", audiobitrate, audiocodecopts, "-af", audiofilteropts, "-hide_banner", "-y", str(outpath)])

        if framerate:
            basecommandpass1.insert(5, ["-filter:v", "fps={}".format(framerate[0])])
            basecommandpass2.insert(5, ["-filter:v", "fps={}".format(framerate[0])])
            basecommand1pass.insert(5, ["-filter:v", "fps={}".format(framerate[0])])

        if not videocodecopts:
            basecommandpass1.remove(videocodecopts)
            basecommandpass2.remove(videocodecopts)
            basecommand1pass.remove(videocodecopts)

        if not audiocodecopts:
            basecommandpass2.remove(audiocodecopts)
            basecommand1pass.remove(audiocodecopts)

        if not audiofilteropts:
            basecommandpass2.remove("-af")
            basecommandpass2.remove(audiofilteropts)
            basecommand1pass.remove("-af")
            basecommand1pass.remove(audiofilteropts)

        if not audiocodec or audiocodec is "none":
            basecommandpass2.remove(audiocodec)
            basecommandpass2.remove("-b:a")
            basecommandpass2.remove(audiobitrate)
            basecommandpass2.remove(audiocodecopts)
            basecommandpass2.remove("-af")
            basecommandpass2.remove(audiofilteropts)
            basecommandpass2.insert(len(basecommandpass2)-2, "-an")

            basecommand1pass.remove(audiocodec)
            basecommand1pass.remove("-b:a")
            basecommand1pass.remove(audiobitrate)
            basecommand1pass.remove(audiocodecopts)
            basecommand1pass.remove("-af")
            basecommand1pass.remove(audiofilteropts)
            basecommand1pass.insert(len(basecommand1pass)-2, "-an")

        if not videocodec or videocodec is "none":
            basecommandpass2.remove(videocodec)
            basecommandpass2.remove("-b:v")
            basecommandpass2.remove(videobitrate)
            basecommandpass2.remove(videocodecopts)
            basecommandpass2.insert(len(basecommandpass2)-2, "-vn")

            basecommand1pass.remove(videocodec)
            basecommand1pass.remove("-b:v")
            basecommand1pass.remove(videobitrate)
            basecommand1pass.remove(videocodecopts)
            basecommand1pass.insert(len(basecommand1pass)-2, "-vn")

        if audiocodec is "copy":
            basecommandpass2.remove("-b:a")
            basecommandpass2.remove(audiobitrate)
            basecommandpass2.remove(audiocodecopts)
            basecommandpass2.remove("-af")
            basecommandpass2.remove(audiofilteropts)

            basecommand1pass.remove("-b:a")
            basecommand1pass.remove(audiobitrate)
            basecommand1pass.remove(audiocodecopts)
            basecommand1pass.remove("-af")
            basecommand1pass.remove(audiofilteropts)

        if videocodec is "copy":
            basecommandpass2.remove("-b:v")
            basecommandpass2.remove(videobitrate)
            basecommandpass2.remove(videocodecopts)

            basecommand1pass.remove("-b:v")
            basecommand1pass.remove(videobitrate)
            basecommand1pass.remove(videocodecopts)

        commandpass1=list(flatten(basecommandpass1))
        commandpass2=list(flatten(basecommandpass2))
        command1pass=list(flatten(basecommand1pass))

        if self.debug:
            print('')
            print(commandpass1)
            print(commandpass2)
            print(command1pass)

        if passes is 2:
            try:
                runprogram(commandpass1)
                runprogram(commandpass2)
            except (KeyboardInterrupt, subprocess.CalledProcessError):
                if filepath.with_suffix(container).exists():
                    print("{} Removing unfinished file.".format(colors.mood("neutral")))
                    runprogram(["rm", str(filepath.with_suffix(container))])
            else:
                if self.database:
                    with self.database:
                        self.db.execute('delete from videoinfo where filename = ?', (filepath.name,))
                if self.backuppath and self.backuppath.exists():
                    print("{} Moving {} to {}".format(colors.mood("happy"), filepath.name, self.backup))
                    shutil.move(str(filepath), self.backup)
            finally:
                if pathlib.Path(filename.replace(filepath.suffix, "-0.log")).exists():
                    print("{} Removing 1st pass log file.".format(colors.mood("neutral")))
                    runprogram(["rm", filename.replace(filepath.suffix, "-0.log")])

        elif passes is 1:
            try:
                runprogram(command1pass)
            except (KeyboardInterrupt, subprocess.CalledProcessError):
                if filepath.with_suffix(container).exists():
                    print("{} Removing unfinished file.".format(colors.mood("neutral")))
                    runprogram(["rm", str(filepath.with_suffix(container))])
            else:
                if self.database:
                    with self.database:
                        #db=self.database.cursor()
                        print("{} Removing {} from the database".format(colors.mood("happy"), filepath.name))
                        self.db.execute('delete from videoinfo where filename = ?', (filepath.name,))
                if self.backuppath and self.backuppath.exists():
                    print("{} Moving {} to {}".format(colors.mood("happy"), filepath.name, self.backup))
                    shutil.move(str(filepath), self.backup)
