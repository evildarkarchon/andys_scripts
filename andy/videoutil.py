import locale
import shutil
import os

from humanize.filesize import naturalsize

from andy.util import Color, Util, Program

locale.setlocale(locale.LC_ALL, "en_US.utf-8")


class VideoUtil:

    def __init__(self):
        self.colors = Color()
        self.util = Util()
        self.program = Program()
        self.mkvpropedit = shutil.which("mkvpropedit", mode=os.X_OK)
        self.ffmpeg = shutil.which("ffmpeg", mode=os.X_OK)
        self.mkvmerge = shutil.which("mkvmerge", mode=os.X_OK)
        self.ffprobe = shutil.which("ffprobe", mode=os.X_OK)
