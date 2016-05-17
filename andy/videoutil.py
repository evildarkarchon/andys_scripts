import locale
import shutil
import os

from andy.util import Color, Util, Program

locale.setlocale(locale.LC_ALL, "en_US.utf-8")


class VideoUtil:
    
    """Compilation of functions that are useful to my video utilities, nothing really here right now, because it was mostly a base class that the VideoInfo class was based off.
    I got rid of that subclassing because when I went to subclass GenVideoInfo from VideoInfo, it was creating a dependency loop.
    Right now, this is just a placeholder."""

    def __init__(self):
    
        """At the moment, its just an invocation of the Color, Util, and Program utility classes
        and variables that get locations of certain important programs from shutil.which"""
        
        self.colors = Color()
        self.util = Util()
        self.program = Program()
        self.mkvpropedit = shutil.which("mkvpropedit", mode=os.X_OK)
        self.ffmpeg = shutil.which("ffmpeg", mode=os.X_OK)
        self.mkvmerge = shutil.which("mkvmerge", mode=os.X_OK)
        self.ffprobe = shutil.which("ffprobe", mode=os.X_OK)
