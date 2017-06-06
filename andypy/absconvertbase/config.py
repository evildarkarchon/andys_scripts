import json
import shlex
import pathlib

from collections import ChainMap

from ..util.genjson import genjson
from ..mood2 import Mood
from .base import ABSConvertBase

class ABSConfig(ABSConvertBase):
    def __init__(self, configfile=pathlib.Path.home().joinpath('.config/absconvert.json'), **kwargs):
        self.configfile = configfile
        assert isinstance(self.configfile, (str, pathlib.Path))
        if not isinstance(self.configfile, pathlib.Path):
            self.configfile = pathlib.Path(self.configfile)
        super().__init__(self, kwargs)

    def parse_config(self):

        confdiff = {}

        try:
            defaults = json.loads(self.configfile.read_text())
        except NameError:
            with self.configfile.open() as data:
                defaults = json.loads(data.read())
        except FileNotFoundError:
            defaults = {}

            defaults["defaults"] = {}
            defaults["defaults"]["video"] = "libvpx-vp9"
            defaults["defaults"]["audio"] = "libopus"
            defaults["defaults"]["container"] = "mkv"
            defaults["defaults"]["passes"] = 2
            defaults["defaults"]["audiofilter"] = "aresample=async=1:min_comp=0.001:first_pts=0"

            defaults["codecs"] = {}
            defaults["codecs"]["libvpx-vp9"] = shlex.split("-threads 4 -tile-columns 2 -frame-parallel 1 -speed 1")
            print(Mood.neutral("Config file not found, generating one with default values."))
            genjson(defaults, str(self.configfile))
        finally:
            if defaults:
                self.config = ChainMap(confdiff, self.cmdline, defaults)
                if self.config:
                    del self.configfile
