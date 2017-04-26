import filemagic
import pathlib
from .util.findexe import findexe


class ABSWebPConvert:
    def __init__(self, filename, mode='lossy', explicit=False, exepath=findexe('convert')):
        self.filename = filename
        self.exepath = exepath
        self.mode = mode
