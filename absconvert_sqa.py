#!/usr/bin/env python3
# pylint: disable=w0611
import argparse
import json
import pathlib
from collections import ChainMap
from sqlalchemy import create_engine  # , Column, Float, Integer, String
# from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.engine.reflection import Inspector

from andy2.videoinfo import VideoData, VideoInfo, VideoJSON, sqa_session
from andy2.util import Mood, Util, Program

args = argparse.ArgumentParser(description="A Basic Simple Converter: A Batch Conversion Frontend for ffmpeg", fromfile_prefix_chars="@", formatter_class=argparse.ArgumentDefaultsHelpFormatter)

video = args.add_argument_group(description="Video options:")
audio = args.add_argument_group(description="Audio Options:")
config = args.add_argument_group(description="Configuration/Testing options:")
fileargs = args.add_argument_group(description="Options for file manipulation:")

video.add_argument("--passes", "-p", choices=[1, 2], type=int, help="Number of video encoding passes.")
video.add_argument("--video-bitrate", "-vb", help="Bitrate for the video codec.")
video.add_argument("--video-codec", "-vc", help="Video codec to use.")
video.add_argument("--frame-rate", "-fr", dest="frame_rate", help="Frame Rate of the video for if ffmpeg has a problem detecting it automatically (especially helps with mpeg-1 files).")
# video.add_argument("--video-options", "-vo", help="Options to pass to ffmpeg regarding the video codec.")  # WIP

audio.add_argument("--audio-bitrate", "-ab", help="Bitrate for the audio codec.")
audio.add_argument("--audio-codec", "-ac", help="Audio codec to use.")
audio.add_argument("--filter", "-f", help="Filter to be applied to the audio.")
# audio.add_argument("--audio-options", "-ao", help="Options to pass to ffmpeg regarding the audio codec")  # WIP

config.add_argument("--database", "-db", help="Location of the video info database.")
config.add_argument("--convert-test", dest="converttest", action="store_true", help="Conversion test, doesn't delete entrys from database.")
config.add_argument("--config", "-c", default=str(pathlib.Path.home().joinpath(".config", "absconvert.json")), help="Location of the configuration file (JSON format).")
config.add_argument("--container", "-ct", help="Container format to put the video in.")
config.add_argument("--no-sort", "-ns", action="store_true", help="Don't sort the list of file(s) to be encoded.")
config.add_argument("--debug", "-d", action="store_true", help="Print variables and exit.")

fileargs.add_argument("--backup", "-b", help="Directory where files will be moved when encoded.")
fileargs.add_argument("--output-dir", "-o", dest="output", help="Directory to output the encoded file(s) to (defaults to previous directory unless you are in your home directory).")

args.add_argument("files", nargs="*", help="Files to encode.")

options = vars(args.parse_args())


def filterfilelist(filelist):
    try:
        whitelist = ['video/x-flv', 'video/mp4', 'video/mp2t', 'video/3gpp', 'video/quicktime', 'video/x-msvideo', 'video/x-ms-wmv', 'video/webm', 'video/x-matroska', 'video/msvideo', 'video/avi', 'application/vnd.rm-realmedia', 'audio/x-pn-realaudio', 'audio/x-matroska', 'audio/ogg', 'video/ogg', 'audio/vorbis', 'video/theora', 'video/3gpp2', 'audio/x-wav', 'audio/wave', 'video/dvd', 'video/mpeg', 'application/vnd.rn-realmedia-vbr', 'audio/vnd.rn-realaudio', 'audio/x-realaudio']

        with magic.Magic(flags=magic.MAGIC_MIME_TYPE) as m:
            for filename in filelist:
                filepath = pathlib.Path(filename)
                if m.id_filename(filename) in whitelist and filepath.is_file():
                    yield str(filepath)
    except NameError:
        whitelist = ['.webm', '.mkv', '.flv', '.vob', '.ogg', '.drc', '.avi', '.wmv', '.yuv', '.rm', '.rmvb', '.asf', '.mp4', '.m4v', '.mpg', '.mp2', '.mpeg', '.mpe', '.mpv', '.3gp', '.3g2', '.mxf', '.roq', '.nsv', '.f4v', '.wav', '.ra', '.mka']
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