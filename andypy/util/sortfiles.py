import pathlib

from .sortentries import sortentries


def sortfiles(pathlist):
    temp = [str(x) for x in pathlist if isinstance(x, pathlib.Path)]
    temp = sortentries(temp)
    return [pathlib.Path(x) for x in temp]
