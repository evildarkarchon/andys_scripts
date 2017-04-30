import pathlib

from ..util.hashfile import hashfile
from ..mood2 import Mood


def genhashlist(files, existinghash=None):
    """Generator function that takes a list of files and a list of existing hashes (if any) and calculates hashes for those files.

    files takes a list containing file names for which hashes will be calculated.

    existinghash takes a dictionary where the filename is the key and the hash is the value, this is optional."""

    for filename in files:
        if existinghash and filename not in existinghash:
            print(Mood.happy("Calculating hash for {}".format(pathlib.Path(filename).name)))
            yield filename, hashfile(filename)
        else:
            print(Mood.happy("Calculating hash for {}".format(pathlib.Path(filename).name)))
            yield filename, hashfile(filename)
