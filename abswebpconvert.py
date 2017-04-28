#!/usr/bin/env python3
import argparse
import pathlib
import os
import itertools  # noqa: F401 pylint: disable=w0611
from andypy.mood2 import Mood  # noqa: F401 pylint: disable=w0611
from andypy.program import Program  # noqa: F401 pylint: disable=w0611
from andypy.util.findexe import findexe
from andypy.util.sortentries import sortentries  # noqa: F401 pylint: disable=w0611
from andypy.abswebpconvert import ABSWebPConvert  # noqa: F401 pylint: disable=w0611


if 'Just Downloaded' in os.getcwd():
    backuparchivedir = pathlib.Path.cwd().parent.joinpath('Original Files')
else:
    backuparchivedir = pathlib.Path.cwd().joinpath('Original Files')
backuparchive = str(backuparchivedir.joinpath("{}.7z".format(backuparchivedir.parent.name)))


parser = argparse.ArgumentParser(description='A "simple" script to convert images to WebP using ImageMagick.', formatter_class=argparse.ArgumentDefaultsHelpFormatter)
mode = parser.add_mutually_exclusive_group()
mode.add_argument('--lossy', action='store_true', help="Encode images in lossy mode.")
mode.add_argument('--lossless', action='store_true', help="Encode images in lossless mode.")
parser.add_argument('--quality', '-q', nargs='?', type=int, default=80, help="Quality factor (0-100).")
parser.add_argument('--no-sort', action='store_false', dest='sort', help="Don't sort the file list.")
parser.add_argument('--backup-archive', nargs='?', type=pathlib.Path, help='Location to store the archive of original images.', default=pathlib.Path(backuparchive))
parser.add_argument('--output-dir', nargs='?', type=pathlib.Path, help='Directory to store the resulting images.', default=pathlib.Path.cwd())
parser.add_argument('--no-archive', action='store_false', dest='archive', help='Disable backing up the source images to an archive.')
parser.add_argument('--keep-original', action='store_true', help='Keep the original files.')
parser.add_argument('--force', action='store_true', help='Move any existing files.')
parser.add_argument('--verbose', '-v', action='store_true', help='Make the script more chatty.')
parser.add_argument('--debug', '-d', action='store_true', help='Print variables and exit')
parser.add_argument('--convert-path', dest='convert', type=str, default=findexe('convert'))
parser.add_argument('files', nargs='+', type=pathlib.Path)

args = vars(parser.parse_args())

explicit = bool(args['lossy'] or args['lossless'])

if args['sort'] and not args['debug']:
    args['files'] = sortentries(args['files'])

if args['debug']:
    print(args)

outmode = None
if args['lossy']:
    outmode = 'lossy'
elif args['lossless']:
    outmode = 'lossless'

if not args['debug'] and not args['output_dir'].exists():
    try:
        args['output_dir'].mkdir(mode=0o755, parents=True, exist_ok=True)
    except TypeError:
        try:
            args['output_dir'].mkdir(mode=0o755, parents=True)
        except FileExistsError:
            if not args['output_dir'].is_file():  # gotta handle the weird edge cases
                pass
            else:
                raise
for i in args['files']:
    cmdline = ABSWebPConvert.cmdline(i, args['output_dir'], verbose=args['verbose'], quality=args['quality'], mode=outmode, explicit=explicit, exepath=args['convert'])
    if not args['debug']:
        Program.runprogram(cmdline)
    else:
        print(Mood.neutral("Command Line for {}:".format(i.name)))
        print(cmdline)
