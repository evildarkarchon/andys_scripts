import locale
import pathlib
import shutil
import sqlite3
import subprocess
import sys
import traceback

from andy.util import Color, Program, Util
from andy.videoinfo import VideoInfo
from andy.videoutil import VideoUtil

locale.setlocale(locale.LC_ALL, "en_US.utf-8")


class ABS(VideoInfo, VideoUtil):

    """Worker class for absconvert

    database specifies the location of the videoinfo database, if any.

    debug specifies whether to run in debug (aka pretend) mode, it basically prints out particular variables and function results, but does not actually execute ffmpeg.

    backup specifies an optional backup directory to move the original file when the conversion is complete.

    output specifies the directory where the resulting file will be encoded to.

    converttest tells the class to not delete any videoinfo entries if they exist."""

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

    def convert(self, filename, videocodec=None, videobitrate=None, audiocodec=None, audiobitrate=None, videocodecopts=None,
                audiocodecopts=None, audiofilteropts=None, container=None, framerate=None, passes=2):
        """Conversion worker function for absconvert, this function is intended to be run in a for loop, but technically can be run outside one.

        filename is the location of the file to be converted.

        videocodec specifies the video codec to be used, if the codec is None, "none", or "copy", certain variables will not be used.

        videobitrate is an optional variable that specifies the bitrate for the video stream.
        If its not specified, and there is a videoinfo database, it will use the highest of the two bitrate entries (or only one if there is only one stream).
        If there is not a videoinfo database and the videocodec is not None, "none", or "copy", it will error out.

        videocodecopts specifies any options to be passed to ffmpeg regarding the video codec.

        audiocodec specifies the audio codec to be used, like videocodec,
        if None, "none", or "copy" is specified, certain variables will not be used.

        audiobitrate is an optional variable that specifies the bitrate for the audio stream.
        If its not specified, and there is a videoinfo database, it will use the lowest of the two bitrate entries in the database (or the only one if there is only one stream).
        If there is not a videoinfo database and the audiocodec is not None, "none", or "copy", it will error out.

        audiocodecopts specifies any options related to the audio codec to be passed to ffmpeg.

        audiofilteropts specifies any audio filters to use.

        container specifies what container format to use.

        framerate tells ffmpeg explicitly what frame rate the video file is, it helps with old containers like MPEG2-PS, if not specified and there is a videoinfo database, that value will automatically be used.

        passes specifies the number of passes to use, defaults to 2."""

        filepath = pathlib.Path(filename).resolve()
        outpath = self.outputpath.joinpath(filepath.with_suffix(container).name)
        output = str(outpath)

        def frameratefilter():
            """Helper function to give the command list function the framerate that was either specified on the command line or from the videoinfo database."""

            if framerate:
                return "-filter:v", "fps={}".format(framerate)
            elif self.vi and not framerate and videocodec not in self.nocodec:
                if self.fr is False:
                    print("{} Frame Rate not specified, attempting to read from the database.".format(self.colors.mood("neutral")))
                    self.fr = True
                try:
                    fr = self.vi.queryvideoinfosr("select frame_rate from videoinfo where filename=?", filepath.name)
                    return "-filter:v", "fps={}".format(fr[0])
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
            """Generator function to assemble the command list.

            passno indicates the stage of a 2 pass encode.

            passmax indicates whether its a 1 or 2 pass encode."""

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
                """Helper function that returns the bitrate(s) in a videoinfo database if not specified."""

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

            if ('videobitrate' not in vars() or not videobitrate) or ('audiobitrate' not in vars() or not audiobitrate):
                bitrates = auto_bitrates()
                if self.debug:
                    print(bitrates)

            if ('videobitrate' not in vars() or not videobitrate) and videocodec not in self.nocodec and len(bitrates) >= 2:
                videobitrate = str(max(bitrates))
                if self.debug:
                    print(videobitrate)
            elif 'videobitrate' not in vars() and videocodec not in self.nocodec\
                    and ('audiocodec' not in vars() or not audiocodec) and len(bitrates) is 1:
                videobitrate = str(bitrates)
                if self.debug:
                    print(videobitrate)

            if 'audiobitrate' not in vars() and audiocodec not in self.nocodec and len(bitrates) >= 2:
                audiobitrate = str(min(bitrates))
                if self.debug:
                    print(audiobitrate)
            elif 'audiobitrate' not in vars() and audiocodec not in self.nocodec and len(bitrates) is 1:
                audiobitrate = str(bitrates)
                if self.debug:
                    print(audiobitrate)

            for item in [self.ffmpeg, "-i", str(filepath)]:
                yield item

            if videocodec not in self.nocodec:
                for item in ["-c:v", videocodec]:
                    yield item
                fr = frameratefilter()
                if fr:
                    yield from frameratefilter()
                for item in ["-b:v", videobitrate]:
                    yield item

            if passmax is 2:
                for item in ["-pass", str(passno), "-passlogfile", str(filepath.with_suffix(""))]:
                    yield item

            if videocodecopts:
                for item in videocodecopts:
                    yield item

            if passno is 1:
                for item in ["-an", "-hide_banner", "-y", "-f", "matroska", "/dev/null"]:
                    yield item
            else:
                if audiocodec not in (None, "none"):
                    for item in ["-c:a", audiocodec]:
                        yield item
                    if audiocodec is not "copy":
                        for item in ["-b:a", audiobitrate]:
                            yield item
                        if audiocodecopts:
                            for item in audiocodecopts:
                                yield item
                        if audiofilteropts:
                            yield "-af"
                            for item in audiofilteropts:
                                yield item
                else:
                    yield "-an"
                for item in ["-hide_banner", "-y", output]:
                    yield item

        def convertdone():
            """Clean up function for when the conversion has completed successfully."""

            if self.vi and not self.converttest:
                self.vi.deletefileentry(filepath.name)
            if self.backuppath and self.backuppath.exists():
                print("{} Moving {} to {}".format(self.colors.mood("happy"), filepath.name, self.backup))
                shutil.move(str(filepath), self.backup)

            if ("mkv" in container or "mka" in container) and self.mkvpropedit:
                print("{} Adding statistics tags to output file.".format(self.colors.mood("happy")))
                self.program.runprogram([self.mkvpropedit, "--add-track-statistics-tags", output])

        def convertnotdone():
            """Clean up function for when conversion does not complete successfully."""

            # print("\ntest")
            if outpath.exists():
                print("\n{} Removing unfinished file.".format(self.colors.mood("neutral")))
                outpath.unlink()
                sys.exit(1)

        if self.debug:
            print('')
            if passes is 2:
                print(list(commandlist(passno=1, passmax=2)))
                print(list(commandlist(passno=2, passmax=2)))
            else:
                print(list(commandlist(passmax=1)))

        if passes is 2 and not self.debug:
            try:
                self.program.runprogram(list(commandlist(passno=1, passmax=2)), verify=True)
                self.program.runprogram(list(commandlist(passno=2, passmax=2)), verify=True)
            # except Exception as e:
            except (KeyboardInterrupt, subprocess.CalledProcessError, ChildProcessError):
                convertnotdone()
                # traceback.print_exc()
                raise
            else:
                convertdone()
            finally:
                if pathlib.Path(filename.replace(filepath.suffix, "-0.log")).exists():
                    print("{} Removing 1st pass log file.".format(self.colors.mood("neutral")))
                    self.program.runprogram(["rm", filename.replace(filepath.suffix, "-0.log")])

        elif passes is 1 and not self.debug:
            try:
                self.program.runprogram(commandlist(passmax=1), verify=True)
            except (KeyboardInterrupt, subprocess.CalledProcessError, ChildProcessError):
                convertnotdone()
                # traceback.print_exc()
                raise
            else:
                convertdone()
