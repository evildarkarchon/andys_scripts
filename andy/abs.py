import sqlite3
import pathlib
import atexit
import subprocess

from andy.runprogram import runprogram
from andy.flatten import flatten

class ABS:
    def __init__(self, database="videoinfo.sqlite", test=None, debug=None):
        self.database=sqlite3.connect(database)
        self.db=self.database.cursor()
        atexit.register(self.database.close)
        self.test=test
        self.debug=debug

    def convert(self, filename, videocodec=None, videobitrate=None, audiocodec=None, audiobitrate=None, videocodecopts=None, audiocodecopts=None, audiofilteropts=None, container=None, passes=2):

        filepath=pathlib.Path(filename)

        if videocodec is "copy" or videocodec is "none" or not videocodec:
            passes=1

        basecommandpass1=["ffmpeg", "-i", str(filepath), "-c:v", videocodec, "-b:v", videobitrate, "-pass", "1", "-passlogfile", str(filepath.with_suffix("")), videocodecopts, "-an", "-hide_banner", "-y", "-f", "matroska", "/dev/null"]
        basecommandpass2=["ffmpeg", "-i", str(filepath), "-c:v", videocodec, "-b:v", videobitrate, "-pass", "2", "-passlogfile", str(filepath.with_suffix("")), videocodecopts, "-c:a", audiocodec, "-b:a", audiobitrate, audiocodecopts, "-af", audiofilteropts, "-hide_banner", "-y", str(filepath.with_suffix(container))]
        basecommand1pass=["ffmpeg", "-i", str(filepath), "c:v", videocodec, "-b:v", videobitrate, videocodecopts, "-c:a", audiocodec, "-b:a", audiobitrate, audiocodecopts, "-af", audiofilteropts, "-hide_banner", "-y", str(filepath.with_suffix(container))]

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
            print(commandpass1)
            print(commandpass2)
            print(command1pass)

        if passes is 2:
            try:
                runprogram(commandpass1)
                runprogram(commandpass2)
            except (KeyboardInterrupt, subprocess.CalledProcessError):
                pathlib.Path(filename.replace(filepath.suffix, "-0.log")).unlink()
        elif passes is 1:
            runprogram(command1pass)

        try:
            self.db.execute('delete from videoinfo where filename=?', filepath.name)
        except sqlite3.Error:
            self.database.rollback()
        else:
            self.database.commit()
