#!/usr/bin/env python3
# pylint:disable=unused-import
import argparse
import json
import pathlib
import shlex
import shutil
import subprocess
from collections import ChainMap

import magic
from sqlalchemy import create_engine
from sqlalchemy.engine.reflection import Inspector
from sqlalchemy.orm import sessionmaker

from andypy.mood2 import Mood
from andypy.program import Program
from andypy.util.cleanlist import cleanlist
from andypy.util.genjson import genjson
from andypy.util.resolvepaths import resolvepaths
from andypy.util.sortentries import sortentries
from andypy.util.sortfiles import sortfiles
from andypy.videoinfodb import VideoData, VideoInfo, VideoJSON, sqa_session

arg = argparse.ArgumentParser(description="A Basic Simple Converter: A Batch Conversion Frontend for ffmpeg", fromfile_prefix_chars="@", formatter_class=argparse.ArgumentDefaultsHelpFormatter)

video = arg.add_argument_group(description="Video options:")
audio = arg.add_argument_group(description="Audio Options:")
config = arg.add_argument_group(description="Configuration/Testing options:")
fileargs = arg.add_argument_group(description="Options for file manipulation:")

video.add_argument("--passes", "-p", choices=[1, 2], type=int, default=2, help="Number of video encoding passes.")
video.add_argument("--video-bitrate", "-vb", dest="video_bitrate", help="Bitrate for the video codec.")
video.add_argument("--video-codec", "-vc", dest="video_codec", type=str, default="libvpx-vp9", help="Video codec to use.")
video.add_argument("--frame-rate", "-fr", dest="frame_rate", type=float, help="Frame Rate of the video for if ffmpeg has a problem detecting it automatically (especially helps with mpeg-1 files).")

audio.add_argument("--audio-bitrate", "-ab", dest="audio_bitrate", help="Bitrate for the audio codec.")
audio.add_argument("--audio-codec", "-ac", dest="audio_codec", type=str, default="libopus", help="Audio codec to use.")
audio.add_argument("--filter", "-f", type=str, help="Filter to be applied to the audio.")

config.add_argument("--database", "-db", type=pathlib.Path, default=pathlib.Path.cwd().joinpath('videoinfo.sqlite'), help="Location of the video info database.")
config.add_argument("--convert-test", dest="convert_test", action="store_true", help="Conversion test, doesn't delete entrys from database.")
config.add_argument("--config", "-c", type=pathlib.Path, default=pathlib.Path.home().joinpath(".config/absconvert.json"), help="Location of the configuration file (JSON format).")
config.add_argument("--container", "-ct", type=str, default="mkv", help="Extension for the container format to put the video in (no dot).")
config.add_argument("--no-sort", "-ns", action="store_false", dest="sort", help="Don't sort the list of file(s) to be encoded.")
config.add_argument("--debug", "-d", action="store_true", help="Print variables and exit.")

fileargs.add_argument("--backup", "-b", type=pathlib.Path, help="Directory where files will be moved when encoded.")
fileargs.add_argument("--output-dir", "-o", dest="output", type=pathlib.Path, default=pathlib.Path.cwd(), help="Directory to output the encoded file(s) to (defaults to previous directory unless you are in your home directory).")

fileargs.add_argument("files", nargs="*", type=pathlib.Path, help="Files to encode.")

args = vars(arg.parse_args())

args["files"] = cleanlist(args["files"])
args["files"] = list(resolvepaths(args["files"]))
if args["sort"]:
    args["files"] = sortfiles(args["files"])

confdiff = {}

try:
    defaults = json.loads(args['config'].read_text())
except NameError:
    with args['config'].open() as data:
        defaults = json.loads(data.read())
except FileNotFoundError:
    defaults = {}

    defaults["defaults"] = {}
    defaults["defaults"]["video"] = "libvpx-vp9"
    defaults["defaults"]["audio"] = "libopus"
    defaults["defaults"]["container"] = "mkv"
    defaults["defaults"]["passes"] = 2
    defaults["defaults"]["audiofilter"] = "aresample=async=1:min_comp=0.001:first_pts=0"

    defaults["codecs"] = {}
    defaults["codecs"]["libvpx-vp9"] = shlex.split("-threads 4 -tile-columns 2 -frame-parallel 1 -speed 1")
    print(Mood.neutral("Config file not found, generating one with default values."))
    genjson(defaults, str(args["config"]))
else:
    config = ChainMap(confdiff, args, defaults)
