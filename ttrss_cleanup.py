#!/usr/bin/env python3
# pylint: disable=line-too-long
import pathlib
from datetime import datetime

from andypy.mood2 import Mood
from andypy.util.datediff import datediff
from andypy.util.sortfiles import sortfiles

files = sortfiles(pathlib.Path("/data/ttrssbackup").rglob("feeds*.tar.xz"))
# print(sortentries(files))

for filepath in files:
    then = datetime.fromtimestamp(filepath.stat().st_mtime)
    filetime = datediff(then)
    if filetime.days > 14:
        print(Mood.neutral("Removing {} from backup directory.".format(filepath.name)))
        filepath.unlink()
