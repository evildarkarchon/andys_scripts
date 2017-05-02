
import os
import pathlib
import shlex
import shutil
import subprocess
import tempfile

from .program import Program


class ConvertMKV:
    def __init__(self, filelist, verbose=False, progs=None, debug=False):
        self.verbose = verbose
        self.debug = debug
        self.filelist = filelist
        if progs and isinstance(progs, dict):
            self.progs = progs
        else:
            self.progs = {'mkvmerge': shutil.which('mkvmerge', mode=os.X_OK), 'ffmpeg': shutil.which('ffmpeg', mode=os.X_OK), 'mkvpropedit': shutil.which('mkvpropedit', mode=os.X_OK)}

    def ffmpegconcat(self, outfile):
        with tempfile.NamedTemporaryFile as t:  # pylint: disable=e1129
            for a in self.filelist:
                t.write("{}\n".format(str(a)))
            t.fsync()
            cmdline = shlex.split("{} -f concat -safe 0 -i {} -c copy {}".format(self.progs['ffmpeg'], t.name, outfile))
            cmdline += self.filelist
            try:
                Program.runprogram(cmdline)
            except (KeyboardInterrupt, subprocess.CalledProcessError, ChildProcessError):
                raise
            else:
                Program.runprogram([self.progs['mkvpropedit'], '--add-track-statistics-tags', outfile])

    def mkvmergeconcat(self, outfile, options=None):
        files = ' + '.join(self.filelist).split()
        cmdline = shlex.split('{} -o'.format(self.progs['mkvmerge']))
        cmdline += outfile
        if options:
            cmdline += options
        cmdline += files
        Program.runprogram(cmdline)

    def mkvmergemux(self, outdir):
        if not isinstance(outdir, pathlib.Path):
            outdir = pathlib.Path(outdir)
        for b in self.filelist:
            if not isinstance(b, pathlib.Path):
                b = pathlib.Path(b)
            cmdline = [self.progs['mkvmerge'], '-o', str(outdir.joinpath(b.with_suffix('.mkv').name)), '=', str(b)]
            Program.runprogram(cmdline)

    def ffmpegmux(self, outdir):
        if not isinstance(outdir, pathlib.Path):
            outdir = pathlib.Path(outdir)
        for b in self.filelist:
            if not isinstance(b, pathlib.Path):
                b = pathlib.Path(b)
            cmdline = [self.progs['ffmpeg'], '-i', str(b), '-c', 'copy', '-f', 'matroska', '-hide_banner', '-y', str(outdir.joinpath(b.with_suffix('.mkv').name))]
            try:
                Program.runprogram(cmdline)
            except (KeyboardInterrupt, subprocess.CalledProcessError, ChildProcessError):
                raise
            else:
                Program.runprogram(self.progs['mkvpropedit'], '--add-track-statistics-tags', str(outdir.joinpath(b.with_suffix('.mkv').name)))
