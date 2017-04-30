#!/usr/bin/env python3
import argparse
import json
import pathlib
import shlex
import shutil
import subprocess

from collections import ChainMap

import magic
from sqlalchemy import create_engine
from sqlalchemy.engine.reflection import Inspector
from sqlalchemy.orm import sessionmaker

from andypy.mood2 import Mood
from andypy.program import Program
from andypy.util.cleanlist import cleanlist
from andypy.util.sortentries import sortentries
from andypy.util.genjson import genjson
from andypy.videoinfodb import (VideoData, VideoInfo, VideoJSON, sqa_session)
