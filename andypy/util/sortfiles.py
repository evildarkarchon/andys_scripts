import pathlib

from .sortentries import sortentries


def sortfiles(pathlist):
    return [pathlib.Path(x) for x in sortentries([str(x) for x in pathlist if isinstance(x, pathlib.Path)])]
