import os
import pathlib
import shlex
import shutil

import magic  # noqa:F401 pylint: disable=e0401, W0611

from .mood2 import Mood
from .program import Program


class ABSWebPConvert:
    @staticmethod
    def cmdline(filename, outdir, verbose=False, quality=None, mode=None, explicit=False, exepath=None):
        if not isinstance(filename, pathlib.Path):
            filename = pathlib.Path(filename)
        if not isinstance(outdir, pathlib.Path):
            outdir = pathlib.Path(outdir)

        cmd = shlex.split("{} {}".format(exepath, filename))
        cmd += shlex.split("-quality {}".format(quality))
        if not explicit:
            with magic.Magic(flags=magic.MAGIC_MIME_ENCODING) as m:  # noqa: F821 pylint: disable=e0602
                lossless = "image/png image/gif image/tiff image/x-pcx application/tga application/x-tga application/x-targs image/tga image/x-tga image/targa image/x-targa image/vnd.adobe.photoshop".split()
                raw = ".3fr .ari .arw .srf .sr2 .bay .crw .cr2 .cap .iiq .eip .dcs .dcr .drf .k25 .kdc .dng .erf .fff .mef .mdc .mos .mrw .nef .nrw .orf .pef .ptx .pxn .r3d .raf .raw .rw2 .rwl .rwz .srw .x3f".split()
                if m.id_filename(str(filename)) in lossless or filename.suffix in raw:
                    mode = 'lossless'
        if mode is 'lossless':
            cmd += shlex.split("-define webp:lossless=true")
        cmd += shlex.split('-define webp:thread-level=1')

        if verbose:
            cmd.append('-verbose')
        cmd.append(str(outdir.joinpath(filename.with_suffix('.webp').name)))
        return cmd

    @staticmethod
    def backuparchive(archive, filelist, exepath=shutil.which('7za', mode=os.X_OK), del_original=False):
        if not isinstance(archive, pathlib.Path):
            archive = pathlib.Path(archive)
        # if del_original:
        #     cmd = shlex.split("{} -sdel a {}".format(exepath, str(archive)))
        # else:
        #     cmd = shlex.split("{} a {}".format(exepath, str(archive)))

        if del_original:
            cmd = [exepath, '-sdel', 'a', str(archive)]
        else:
            cmd = [exepath, 'a', str(archive)]

        if isinstance(filelist, (list, tuple)):
            cmd.extend(filelist)
        elif isinstance(filelist, str):
            cmd.append(filelist)
        print(Mood.happy("Archiving source files to {}".format(archive)))
        Program.runprogram(cmd)

    @staticmethod
    def backup(source, destdir):
        if not isinstance(source, pathlib.Path):
            pathlib.Path(source)

        if not isinstance(destdir, pathlib.Path):
            pathlib.Path(destdir)

        if not destdir.exists():
            try:
                destdir.mkdir(mode=0o755, parents=True)
            except FileExistsError:
                if destdir.is_file():
                    destdir.rename(destdir.with_suffix('.bak'))
                destdir.mkdir(mode=0o755, parents=True)

        print(Mood.happy("Moving {} to {}".format(source.name, destdir)))
        source.rename(destdir.joinpath(source.name))
