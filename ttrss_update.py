#!/usr/bin/env python3
# pylint: disable=line-too-long
import atexit
import pathlib
import argparse

from andy.util import Mood, Util, Program
from andy.git import Git

args = argparse.ArgumentParser()
args.add_argument("--aggressive", "-a", action="store_true", help="Run garbage collection in aggressive mode")
args.add_argument("--replace", "-r", action="store_true", help="Rename any existing directory if a repository is not found.")
options = vars(args.parse_args())

ttrss = Git("/data/web/feeds", use_sudo=True, sudo_user="nginx")

atexit.register(ttrss.clean_lock)


def ttrssgcfile():
    if not Util.is_privileged():
        Program.runprogram(["touch", "/var/cache/ttrssgc"], use_sudo=True, user="root")
    else:
        pathlib.Path("/var/cache/ttrssgc").touch()


if not pathlib.Path("/var/cache/ttrssgc").is_file():
    ttrssgcfile()


def ttrssgc(then):
    diff = Util.datediff(then)
    if diff.days > 30:
        ttrss.gc(aggressive=options["aggressive"])
        ttrssgcfile()


if pathlib.Path("/data/web/feeds/.git").is_dir():
    ttrss.clean_lock()
    ttrss.pull()
elif pathlib.Path("/data/web/feeds").exists() and not pathlib.Path("/data/web/feeds/.git").exists():
    if options["replace"]:
        Program.runprogram(["mv", "/data/web/feeds", "/data/web/feeds.old"], use_sudo=True, user="nginx")
        ttrss.clone("https://tt-rss.org/gitlab/fox/tt-rss.git")
    else:
        print("{} No git repository located in the target directory.".format(Mood.sad()))
        raise FileNotFoundError
elif pathlib.Path("/data/web/feeds").is_file():
    print("{} Target location is a file, renaming and cloning repository.".format(Mood.sad()))
    Program.runprogram(["mv", "/data/web/feeds", "/data/web/feeds.bad"], use_sudo=True, user="nginx")
    ttrss.clone("https://tt-rss.org/gitlab/fox/tt-rss.git")
else:
    print("{} Target location does not exist, cloning repository.".format(Mood.neutral()))
    ttrss.clone("https://tt-rss.org/gitlab/fox/tt-rss.git")

ttrssgc(pathlib.Path("/var/cache/ttrssgc").stat().st_mtime)