#!/usr/bin/env python3
# pylint: disable=line-too-long
import argparse
import atexit
import pathlib
import shlex

from andypy.git import Git
# from andypy.util import Mood, Program, Util
from andypy.mood2 import Mood
from andypy.program import Program
from andypy.util.datediff import datediff
from andypy.util.touchfile import touchfile

args = argparse.ArgumentParser()
args.add_argument("--aggressive", "-a", action="store_true", help="Run garbage collection in aggressive mode")
args.add_argument("--replace", "-r", action="store_true", help="Rename any existing directory if a repository is not found.")
args.add_argument("--restart-ttrssd", action="store_true", dest="restart", help="Restart ttrssd")
options = vars(args.parse_args())

ttrss = Git("/data/web/feeds", use_sudo=True, sudo_user="nginx")

atexit.register(ttrss.clean_lock)
if options["restart"]:
    atexit.register(Program.runprogram, shlex.split("systemctl restart ttrssd"), use_sudo=True)

'''
def ttrssgcfile():
    if not is_privileged():
        Program.runprogram(["touch", "/var/cache/ttrssgc"], use_sudo=True, user="root")
    else:
        pathlib.Path("/var/cache/ttrssgc").touch()
'''

if not pathlib.Path("/var/cache/ttrssgc").is_file():
    touchfile('/var/cache/ttrssgc')


def ttrssgc(then):
    diff = datediff(then)
    if diff.days > 30:
        ttrss.gc(aggressive=options["aggressive"])
        touchfile('/var/cache/ttrssgc')


if pathlib.Path("/data/web/feeds/.git").is_dir():
    ttrss.clean_lock()
    ttrss.pull()
elif pathlib.Path("/data/web/feeds").exists() and not pathlib.Path("/data/web/feeds/.git").exists():
    if options["replace"]:
        # Program.runprogram(["mv", "/data/web/feeds", "/data/web/feeds.old"], use_sudo=True, user="nginx")
        Program.runprogram(shlex.split("mv /dev/web/feeds /data/web/feeds.old"), use_sudo=True, user="nginx")
        ttrss.clone("https://tt-rss.org/gitlab/fox/tt-rss.git")
    else:
        print(Mood.sad("No git repository located in the target directory."))
        raise FileNotFoundError
elif pathlib.Path("/data/web/feeds").is_file():
    print(Mood.sad("Target location is a file, renaming and cloning repository."))
    # Program.runprogram(["mv", "/data/web/feeds", "/data/web/feeds.bad"], use_sudo=True, user="nginx")
    Program.runprogram(shlex.split("mv /data/web/feeds /data/web/feeds.bad"), use_sudo=True, user="nginx")
    ttrss.clone("https://tt-rss.org/gitlab/fox/tt-rss.git")
else:
    print(Mood.neutral("{Target location does not exist, cloning repository."))
    ttrss.clone("https://tt-rss.org/gitlab/fox/tt-rss.git")

ttrssgc(pathlib.Path("/var/cache/ttrssgc").stat().st_mtime)
