import locale
import pathlib
import shutil
import sqlite3
import subprocess

from andy.util import Color, Program, Util
from andy.videoinfo import VideoInfo
from andy.videoutil import VideoUtil

locale.setlocale(locale.LC_ALL, "en_US.utf-8")


class ABS(VideoInfo, VideoUtil):

    def __init__(self, database=str(pathlib.Path.cwd().joinpath("videoinfo.sqlite")), debug=None, backup=None, output=None, converttest=False):
        if pathlib.Path(database).exists():
            VideoInfo.__init__(self, database)
            self.vi = VideoInfo(database)
        VideoUtil.__init__(self)
        self.debug = debug

        self.colors = Color()
        self.util = Util()
        self.program = Program()

        if backup:
            self.backuppath = pathlib.Path(backup).resolve()
            self.backup = str(self.backuppath)
        else:
            self.backuppath = None
            self.backup = None

        if output:
            self.outputpath = pathlib.Path(output).resolve()
        else:
            self.outputpath = pathlib.Path.cwd()

        self.output = str(self.outputpath)

        self.converttest = converttest

        self.auto = False
        self.fr = False

        self.nocodec = (None, "none", "copy")

        if not self.ffmpeg:
            print("{} ffmpeg not found, exiting.")
            raise FileNotFoundError

    def convert(self, filename, videocodec=None, videobitrate=None, audiocodec=None, audiobitrate=None, videocodecopts=None, audiocodecopts=None, audiofilteropts=None, container=None, framerate=None, passes=2):

        filepath = pathlib.Path(filename).resolve()
        outpath = self.outputpath.joinpath(filepath.with_suffix(container).name)
        output = str(outpath)

        def frameratefilter():
            if framerate:
                return ["-filter:v", "fps={}".format(framerate)]
            elif self.vi and not framerate and videocodec not in self.nocodec:
                if self.fr is False:
                    print("{} Frame Rate not specified, attempting to read from the database.".format(self.colors.mood("neutral")))
                    self.frcount = True
                try:
                    fr = self.vi.queryvideoinfosr("select frame_rate from videoinfo where filename=?", filepath.name)
                    return ["-filter:v", "fps={}".format(fr[0])]
                except (sqlite3.Error, IndexError):
                    print("{} Frame Rate for {} not found in database, will rely on ffmpeg auto-detection.".format(self.colors.mood("neutral"), filename))
                    return None
                    pass
            elif not self.vi and not framerate:
                print("{} Frame Rate not specified and there is no videoinfo database, will rely on ffmpeg auto-detection.".format(self.colors.mood("neutral")))
                return None

        if videocodec in self.nocodec or not videocodec:
            passes = 1

        def commandlist(passno=None, passmax=passes):
            if passno is None and passmax is 2:
                print("{} You must specify a pass number if using 2-pass encoding.".format(self.colors.mood("sad")))
                raise ValueError

            if passmax not in (1, 2):
                print("{} The maximum pass variable can only be 1 or 2.".format(self.colors.mood("sad")))
                raise ValueError

            if isinstance(passno, int) and (passno >= 2 and passmax is 1):
                print("{} is >=2 and the maximum number of passes is set to 1.".format(self.colors.mood("sad")))
                raise ValueError

            def auto_bitrates():
                if self.database:
                    if self.auto is False:
                        print("{} Bit-rates not specified, attempting to guess from database entries.".format(self.colors.mood("neutral")))
                        self.auto = True

                    streams = self.vi.queryvideoinfosr("select streams from videoinfo where filename=?", filepath.name)[0]
                    bitrates = self.vi.queryvideoinfosr("select bitrate_0_raw, bitrate_1_raw from videoinfo where filename=?", filepath.name)
                    if streams >= 2:
                        return [bitrates[0], bitrates[1]]
                    elif streams is 1:
                        return bitrates[0]
                else:
                    return None
            if ('videobitrate' not in vars() and 'audiobitrate' not in vars()) or (not videobitrate and not audiobitrate):
                bitrates = auto_bitrates()
                if self.debug:
                    print(bitrates)

            if ('videobitrate' not in vars() or not videobitrate) and videocodec not in self.nocodec and len(bitrates) is 2:
                videobitrate = str(max(bitrates))
                if self.debug:
                    print(videobitrate)
            elif 'videobitrate' not in vars() and videocodec not in self.nocodec and ('audiocodec' not in vars() or not audiocodec) and len(bitrates) is 1:
                videobitrate = str(bitrates)
                if self.debug:
                    print(videobitrate)

            if 'audiobitrate' not in vars() and audiocodec not in self.nocodec and len(bitrates) is 2:
                audiobitrate = str(min(bitrates))
                if self.debug:
                    print(audiobitrate)
            elif 'audiobitrate' not in vars() and audiocodec not in self.nocodec and len(bitrates) is 1:
                audiobitrate = str(bitrates)
                if self.debug:
                    print(audiobitrate)

            biglist = []
            baselist = [self.ffmpeg, "-i", str(filepath)]
            videocodeclist = ["-c:v", videocodec]
            bitratelist = ["-b:v", videobitrate]
            passlist = ["-pass", str(passno), "-passlogfile", str(filepath.with_suffix(""))]
            listsuffix = ["-hide_banner", "-y"]

            biglist = biglist + baselist

            if videocodec not in self.nocodec:
                biglist = biglist + videocodeclist
                fr = frameratefilter()
                if fr:
                    biglist = biglist + fr
                biglist = biglist + bitratelist

            if passmax is 2:
                biglist = biglist + passlist

            if videocodecopts:
                biglist = biglist + videocodecopts

            if passno is 1:
                biglist = biglist + ["-an"] + listsuffix + ["-f", "matroska", "/dev/null"]
            else:
                if audiocodec not in (None, "none"):
                    biglist = biglist + ["-c:a"] + [audiocodec]
                    if audiocodec is not "copy":
                        biglist = biglist + ["-b:a"] + [audiobitrate]
                        if audiocodecopts:
                            biglist = biglist + audiocodecopts
                        if audiofilteropts:
                            biglist = biglist + ["-af"] + audiofilteropts
                else:
                    biglist.append("-an")
                biglist = biglist + listsuffix + [output]

            # print(list(flatten(biglist))) #temporary for debugging purposes

            return biglist

        def convertdone():
            if self.vi and not self.converttest:
                print("{} Removing {} from the database".format(self.colors.mood("happy"), filepath.name))
                self.vi.deletefileentry(filepath.name)
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
