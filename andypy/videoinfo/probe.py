import shutil
import os
import json

from ..mood2 import Mood
from ..program import Program


def probe(videofile, prog=None, quiet=False):
    """Function used to extract video information from files as json data and return a dictionary based on that data.

    prog defines an alternate program to use (if any), this is an optional parameter.

    quiet is pretty much just that, don't print anything to the terminal."""

    ffprobe = None
    if prog:
        ok = os.access(prog, mode=os.X_OK, effective_ids=True)  # pylint: disable=c0103
        if ok:
            ffprobe = prog
            del prog
            del ok
        else:
            raise FileNotFoundError("Specified ffprobe compatible command not found or not executable by current user.")
    else:
        ffprobe = shutil.which("ffprobe", mode=os.X_OK)

    if not ffprobe:
        raise FileNotFoundError("Could not find ffprobe.")
    if not quiet:
        print(Mood.happy("Extracting information from {}".format(videofile)))
    return json.loads(Program.returninfo([ffprobe, "-i", videofile, "-hide_banner", "-of", "json", "-show_streams", "-show_format"], string=True))
