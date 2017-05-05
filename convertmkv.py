import argparse
import os
import pathlib
import shutil

from andypy.convertmkv import ConvertMKV
from andypy.util.cleanlist import cleanlist
from andypy.util.resolvepaths import resolvepaths
from andypy.util.sortfiles import sortfiles

parser = argparse.ArgumentParser(description="Small script that wraps existing video or audio file(s) in a matroska container using mkvmerge or ffmpeg.")
parser.add_argument('--database', '-d', nargs='?', help='Database to read metadata from (if any).')
parser.add_argument('--combine', '-c', action='store_true', help='Run in concatenation mode.')
parser.add_argument('--no-sort', action='store_false', dest='sort', help='Do not sort the file list.')
parser.add_argument('--gvi', action='store_true', help='Generate metadata and add it to an sqlite database.')
parser.add_argument('--output', '-o', metavar='directory', type=pathlib.Path, default=pathlib.Path.cwd(), help='Destination directory for output file(s)')
parser.add_argument('--backup', '-b', metaver='directory', type=pathlib.Path, default=pathlib.Path.cwd().joinpath('Original Files'), help='Directory to move the source file(s)')
parser.add_argument('--verbose', '-v', action='store_true', help='Makes the script more chatty.')
parser.add_argument('--debug', '-d', action='store_true', help="Print what would be done, but don't actually do it")
parser.add_argument('--config', nargs='?', type=pathlib.Path, default=pathlib.Path.home().joinpath('.config/configmkv.json'), help='Location for the configuration file')
parser.add_argument('--ffmpeg', '-f', action='store_true', help='Use ffmpeg instead of mkvmerge. Note: ffmpeg hates mpeg2-ps files.')
parser.add_argument('files', nargs='+', type=pathlib.Path)

args = vars(parser.parse_args())
args['files'] = cleanlist(args['files'])

if args['sort:']:
    args['files'] = sortfiles(args['files'])

args['files'] = resolvepaths(args['files'])

# programs = {'ffmpeg': shutil.which('ffmpeg', mode=os.X_OK), 'mkvmerge': shutil.which('mkvmerge', mode=os.X_OK), 'mkvpropedit': shutil.which('mkvpropedit', mode=os.X_OK)}
programs = {'mkvpropedit': shutil.which('mkvpropedit', mode=os.X_OK)}
if args['ffmpeg']:
    programs['ffmpeg'] = shutil.which('ffmpeg', mode=os.X_OK)
else:
    programs['mkvmerge'] = shutil.which('mkvmerge', mode=os.X_OK)

convert = ConvertMKV(args['files'], args['output'], verbose=args['verbose'], debug=args['debug'], progs=programs)

if args['ffmpeg'] and args['combine']:
    convert.ffmpegconcat()
elif not args['ffmpeg'] and args['combine']:
    convert.mkvmergeconcat()
elif args['ffmpeg'] and not args['combine']:
    convert.ffmpegmux()
else:
    convert.mkvmergemux()
