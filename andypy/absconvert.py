# pylint:disable=unused-import
import json
import shlex
import pathlib

import magic

from .mood2 import Mood
from .program import Program
from .videoinfodb import VideoInfo, VideoJSON, sqa_session
from .absconvertbase.base import ABSConvertBase
from .absconvertbase.config import ABSConfig
from .absconvertbase.metadata import ABSMetadata

class ABSConvert(ABSMetadata, ABSConfig, ABSConvertBase):
    def __init__(self, **kwargs):
        ABSConvertBase.__init__(self, kwargs)
        ABSConfig.__init__(self, kwargs)
        ABSMetadata.__init__(self, kwargs)

        self.parse_config()
        self.parse_metadata()
