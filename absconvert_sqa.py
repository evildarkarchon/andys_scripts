#!/usr/bin/env python3
# pylint: disable=w0611, c0301, c0103, c0111, R0902
import argparse
import json
import os
import pathlib
import shutil
import sys
from collections import ChainMap

from sqlalchemy import create_engine  # , Column, Float, Integer, String
from sqlalchemy.engine.reflection import Inspector
# from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

from andy2.util import Mood, Program, Util  # noqa: F401
from andy2.videoinfo import (VideoData, VideoInfo, VideoJSON,  # noqa: F401
                             sqa_session)

arg = argparse.ArgumentParser(description="A Basic Simple Converter: A Batch Conversion Frontend for ffmpeg", fromfile_prefix_chars="@", formatter_class=argparse.ArgumentDefaultsHelpFormatter)

video = arg.add_argument_group(description="Video options:")
audio = arg.add_argument_group(description="Audio Options:")
config = arg.add_argument_group(description="Configuration/Testing options:")
fileargs = arg.add_argument_group(description="Options for file manipulation:")

video.add_argument("--passes", "-p", choices=[1, 2], type=int, help="Number of video encoding passes.")
video.add_argument("--video-bitrate", "-vb", dest="video_bitrate", help="Bitrate for the video codec.")
video.add_argument("--video-codec", "-vc", dest="video_codec", help="Video codec to use.")
video.add_argument("--frame-rate", "-fr", dest="frame_rate", help="Frame Rate of the video for if ffmpeg has a problem detecting it automatically (especially helps with mpeg-1 files).")
# video.add_argument("--video-options", "-vo", help="Options to pass to ffmpeg regarding the video codec.")  # WIP

audio.add_argument("--audio-bitrate", "-ab", dest="audio_bitrate", help="Bitrate for the audio codec.")
audio.add_argument("--audio-codec", "-ac", dest="audio_codec", help="Audio codec to use.")
audio.add_argument("--filter", "-f", help="Filter to be applied to the audio.")
# audio.add_argument("--audio-options", "-ao", help="Options to pass to ffmpeg regarding the audio codec")  # WIP

config.add_argument("--database", "-db", help="Location of the video info database.")
config.add_argument("--convert-test", dest="converttest", action="store_true", help="Conversion test, doesn't delete entrys from database.")
config.add_argument("--config", "-c", default=str(pathlib.Path.home().joinpath(".config", "absconvert.json")), help="Location of the configuration file (JSON format).")
config.add_argument("--container", "-ct", help="Container format to put the video in.")
config.add_argument("--no-sort", "-ns", action="store_true", dest="no_sort", help="Don't sort the list of file(s) to be encoded.")
config.add_argument("--debug", "-d", action="store_true", help="Print variables and exit.")

fileargs.add_argument("--backup", "-b", help="Directory where files will be moved when encoded.")
fileargs.add_argument("--output-dir", "-o", dest="output", help="Directory to output the encoded file(s) to (defaults to previous directory unless you are in your home directory).")

arg.add_argument("files", nargs="*", help="Files to encode.")

options = vars(arg.parse_args())


def filterfilelist(filelist):
    try:
        whitelist = ['video/x-flv', 'video/mp4', 'video/mp2t', 'video/3gpp', 'video/quicktime', 'video/x-msvideo', 'video/x-ms-wmv', 'video/webm', 'video/x-matroska', 'video/msvideo', 'video/avi', 'application/vnd.rm-realmedia', 'audio/x-pn-realaudio', 'audio/x-matroska', 'audio/ogg', 'video/ogg', 'audio/vorbis', 'video/theora', 'video/3gpp2']
        whitelist = whitelist + ['audio/x-wav', 'audio/wave', 'video/dvd', 'video/mpeg', 'application/vnd.rn-realmedia-vbr', 'audio/vnd.rn-realaudio', 'audio/x-realaudio']

        with magic.Magic(flags=magic.MAGIC_MIME_TYPE) as m:
            for filename in filelist:
                filepath = pathlib.Path(filename)
                if m.id_filename(filename) in whitelist and filepath.is_file():
                    yield str(filepath)
    except NameError:
        whitelist = ['.webm', '.mkv', '.flv', '.vob', '.ogg', '.drc', '.avi', '.wmv', '.yuv', '.rm', '.rmvb', '.asf', '.mp4', '.m4v', '.mpg', '.mp2', '.mpeg', '.mpe', '.mpv']
        whitelist = whitelist + ['.3gp', '.3g2', '.mxf', '.roq', '.nsv', '.f4v', '.wav', '.ra', '.mka']
        for filename in filelist:
            filepath = pathlib.Path(filename)
            if filepath.suffix in whitelist and filepath.is_file():
                yield str(filepath)


def configdict():
    if ('config' not in options or not options["config"]) or not pathlib.Path(options["config"]).exists():
        print("{} Could not find configuration file or one was not specified, generating one with default values.".format(Mood.neutral()))
        defaultconfig = {}

        defaultconfig["defaults"] = {}
        defaultconfig["defaults"]["video"] = "libvpx-vp9"
        defaultconfig["defaults"]["audio"] = "libopus"
        defaultconfig["defaults"]["container"] = "mkv"
        defaultconfig["defaults"]["passes"] = 2
        defaultconfig["defaults"]["audiofilter"] = ["aresample=async=1:min_comp=0.001:first_pts=0"]

        defaultconfig["codecs"] = {}
        defaultconfig["codecs"]["libvpx-vp9"] = ["-threads", "4", "-tile-columns", "6", "-frame-parallel", "1", "-speed", "1"]

        if not options["debug"]:
            Util.genjson(defaultconfig, str(pathlib.Path.home().joinpath(".config", "absconvert.json")))

        return ChainMap(options, defaultconfig)
    else:
        with open(options["config"]) as jsonsource:
            config = json.loads(jsonsource.read())  # pylint: disable=W0621

        return ChainMap(options, config)


options = configdict()

database = create_engine("sqlite:///{}".format(options["database"]))
sm = sessionmaker(bind=database)
session = sm()
inspect = Inspector.from_engine(database)

options["files"] = list(filterfilelist(options["files"]))

if not options["no_sort"]:
    options["files"] = Util.sortentries(options["files"])


class Metadata:  # pylint: disable=R0903

    def __init__(self, filename):
        self.filename = str(pathlib.Path(filename).name)
        self.data = session.query(VideoInfo).filter(VideoInfo.filename == self.filename).one()

        if options["container"]:
            self.container = options["container"]
        else:
            self.container = self.data.container

        if options["video_bitrate"]:
            self.video_bitrate = options["video_bitrate"]
        elif self.data.type_0 == "video":
            self.video_bitrate = self.data.bitrate_0_raw
        elif self.data.type_1 == "video":
            self.video_bitrate = self.data.bitrate_1_raw

        if options["audio_bitrate"]:
            self.audio_bitrate = options["audio_bitrate"]
        elif self.data.type_0 == "audio":
            self.audio_bitrate = self.data.bitrate_0_raw
        elif self.data.type_1 == "audio":
            self.audio_bitrate = self.data.bitrate_1_raw

        if options["frame_rate"]:
            self.framerate = options["frame_rate"]
        else:
            self.framerate = self.data.frame_rate


class Cleanup:  # pylint: disable=R0903

    def __init__(self, filename, backuppath=None):
        self.filepath = pathlib.Path(filename)
        self.filename = self.filepath.name
        if backuppath:
            self.backuppath = pathlib.Path(backuppath)
        else:
            self.backuppath = None
        self.metadata = Metadata(filename)

        self.mkvpropedit = shutil.which("mkvpropedit", mode=os.X_OK)

    def success(self):
        with sqa_session(session) as sess:
            sess.query(VideoInfo).filter(VideoInfo.filename == self.filename).delete()

        if self.backuppath and self.backuppath.exists():
            print("{} Moving {} to {}".format(Mood.happy(), self.filepath.name, self.backuppath))
            shutil.move(str(self.filepath), str(self.backuppath))
        elif self.backuppath and not self.backuppath.exists():
            self.backuppath.mkdir(parents=True, exist_ok=True)
            shutil.move(str(self.filepath), str(self.backuppath))

        if ("mkv" in self.metadata.data.container or "mka" in self.metadata.container) and self.mkvpropedit:
            print("{} Adding statistics tags to output file.".format(Mood.happy()))
            Program.runprogram([self.mkvpropedit, "--add-track-statistics-tags", str(self.filepath)])

    def fail(self):
        if self.filepath.exists():
            print("\n{} Removing unfinished file.".format(Mood.neutral()))
            self.filepath.unlink()
            sys.exit(1)


class Command:  # pylint: disable = R0903

    def __init__(self, filename):  # pylint: disable=w0613
        self.metadata = Metadata(filename)
        self.filename = filename
        self.filepath = pathlib.Path(filename)
        self.mkvpropedit = shutil.which("mkvpropedit", mode=os.X_OK)
        self.ffmpeg = shutil.which("ffmpeg", mode=os.X_OK)
        self.mkvmerge = shutil.which("mkvmerge", mode=os.X_OK)
        self.ffprobe = shutil.which("ffprobe", mode=os.X_OK)
        if options["backup"]:
            self.cleanup = Cleanup(filename, backuppath=pathlib.Path(options["backup"]))  # pylint: disable=unused-variable
        else:
            self.cleanup = Cleanup(filename)

    def convert(self, passnum=None, passmax=1):
        if passnum is None and passmax is 2:
            print("{} You must specify a pass number if using 2-pass encoding.".format(Mood.sad()))
            raise ValueError

        if passmax not in (1, 2):
            print("{} The maximum pass variable can only be 1 or 2.".format(Mood.sad()))
            raise ValueError

        if isinstance(passnum, int) and (passnum >= 2 and passmax is 1):
            print("{} is >=2 and the maximum number of passes is set to 1.".format(Mood.sad()))
            raise ValueError

        cmd = [self.ffmpeg, "-hide_banner", "-i", str(self.filepath.resolve()), '-y']  # pylint: disable=unused-variable
        if not options["audio_codec"] or options["audio_codec"] == "none":
            cmd = cmd + '-an'
        else:
            cmd = cmd + ['-c:a', options["audio_codec"], '-b:a', self.metadata.audio_bitrate] + ['-af', options["defaults"]["audiofilter"]]

        if not options["video_codec"] or options["video_codec"] == "none":
            cmd = cmd + '-vn'
        else:
            cmd = cmd + ['-c:v', options["video_codec"], '-b:v', self.metadata.video_bitrate] + options["codecs"][options["video_codec"]]

        if passmax == 2:
            cmd = cmd + ['-pass', passnum, '--passlogfile', self.filepath.stem]

        if passnum == 1 and passmax == 2:
            cmd = cmd + ['-f', 'matroska', '/dev/null']

        if (passnum == 2 and passmax == 2) or passmax == 1:
            if options["container"]:
                cmd = cmd + self.filepath.with_suffix(".{}".format(options["container"]))
            else:
                cmd = cmd + str(self.filepath.with_suffix(".{}".format(options["defaults"]["container"])))
