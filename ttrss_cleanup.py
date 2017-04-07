#!/usr/bin/env python3
# pylint: disable=line-too-long
import pathlib
from datetime import datetime

from andy.util import Mood, Util

now = datetime.now()

files = Util.sortentries(pathlib.Path("/data/ttrssbackup").rglob("feeds*.tar.xz"))
# print(sortentries(files))

for filepath in files:
    then = datetime.fromtimestamp(filepath.stat().st_mtime)
    filetime = now - then
    if filetime.days > 14:
        print("{} Removing {} from backup directory.".format(Mood.neutral(), filepath.name))
        filepath.unlink()