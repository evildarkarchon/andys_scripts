
import os
import pathlib
import shlex
import shutil
import subprocess
import tempfile

from .program import Program


class ConvertMKV:
    def __init__(self, filelist, out, verbose=False, progs=None, debug=False):
        self.verbose = verbose
        self.debug = debug
        self.filelist = filelist
        if isinstance(out, pathlib.Path):
            self.out = out
        else:
            self.out = pathlib.Path(out)
        if progs and isinstance(progs, dict):
            self.progs = progs
        else:
            self.progs = {'mkvmerge': shutil.which('mkvmerge', mode=os.X_OK), 'ffmpeg': shutil.which('ffmpeg', mode=os.X_OK), 'mkvpropedit': shutil.which('mkvpropedit', mode=os.X_OK)}

    def ffmpegconcat(self):
        with tempfile.NamedTemporaryFile as t:  # pylint: disable=e1129
            for a in self.filelist:
                t.write("{}\n".format(str(a)))
            t.fsync()
            cmdline = shlex.split("{} -f concat -safe 0 -i {} -c copy {}".format(self.progs['ffmpeg'], t.name, self.out))
            cmdline += self.filelist
            if self.debug:
                print("FFMPEG Concatenation Comand Line:")
                print(cmdline)
            else:
                try:
                    Program.runprogram(cmdline)
                except (KeyboardInterrupt, subprocess.CalledProcessError, ChildProcessError):
                    raise
                else:
                    Program.runprogram([self.progs['mkvpropedit'], '--add-track-statistics-tags', self.out])

    def mkvmergeconcat(self):
        files = ' + '.join(self.filelist).split()
        cmdline = shlex.split('{} -o'.format(self.progs['mkvmerge'])).append(self.out).extend(files)
        if self.debug:
            print("MkvMerge Concatenation Command Line:")
            print(cmdline)
        else:
            Program.runprogram(cmdline)

    def mkvmergemux(self):
        for b in self.filelist:
            if not isinstance(b, pathlib.Path):
                b = pathlib.Path(b)
            cmdline = [self.progs['mkvmerge'], '-o', str(self.out.joinpath(b.with_suffix('.mkv').name)), '=', str(b)]
            if self.debug:
                print("MkvMerge Muxing Command Line:")
            else:
                Program.runprogram(cmdline)

    def ffmpegmux(self):
        for b in self.filelist:
            if not isinstance(b, pathlib.Path):
                b = pathlib.Path(b)
            # cmdline = [self.progs['ffmpeg'], '-i', str(b), '-c', 'copy', '-f', 'matroska', '-hide_banner', '-y', str(self.out.joinpath(b.with_suffix('.mkv').name))]
            cmdline = shlex.split("{} -i {} -c copy -f matroska -hide_banner -y".format(self.progs['ffmpeg'], str(b))).append(str(self.out.joinpath(b.with_suffix('.mkv').name)))

            if self.debug:
                print("FFMPEG Muxing Command Line:")
                print(cmdline)
            else:
                try:
                    Program.runprogram(cmdline)
                except (KeyboardInterrupt, subprocess.CalledProcessError, ChildProcessError):
                    raise
                else:
                    mpecmd = shlex.split("{} --add-track-statistics-tags".format(self.progs['mkvpropedit'])).append(str(self.out.joinpath(b.with_suffix('.mkv').name)))
                    Program.runprogram(mpecmd)
                    # Program.runprogram([self.progs['mkvpropedit'], '--add-track-statistics-tags', str(self.out.joinpath(b.with_suffix('.mkv').name))])
