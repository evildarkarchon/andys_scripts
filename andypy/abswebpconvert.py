import pathlib
import shlex
import filemagic  # noqa:F401 pylint: disable=e0401, W0611
from .util.findexe import findexe
from .program import Program
from .mood2 import Mood


class ABSWebPConvert:
    @staticmethod
    def cmdline(filename, outdir, verbose=False, quality=80, mode='lossy', explicit=False, exepath=findexe('convert')):
        cmd = shlex.split("{} {}".format(exepath, filename))
        cmd.extend(shlex.split("-quality {}".format(quality)))
        if not explicit:
            with magic.Magic(flags=magic.MAGIC_MIME_ENCODING) as m:  # noqa: F821 pylint: disable=e0602
                lossless = "image/png image/gif image/tiff image/x-pcx application/tga application/x-tga application/x-targs image/tga image/x-tga image/targa image/x-targa image/vnd.adobe.photoshop".split(' ')
                raw = ".3fr .ari .arw .srf .sr2 .bay .crw .cr2 .cap .iiq .eip .dcs .dcr .drf .k25 .kdc .dng .erf .fff .mef .mdc .mos .mrw .nef .nrw .orf .pef .ptx .pxn .r3d .raf .raw .rw2 .rwl .rwz .srw .x3f".split(' ')
                if m.id_filename(filename) in lossless or filename.suffix in raw:
                    mode = 'lossless'
        if mode is 'lossless':
            cmd.extend(shlex.split("-define webp:lossless=true"))
        cmd.extend(shlex.split('-define webp:thread-level=1'))
        if verbose:
            cmd.append('-verbose')
        cmd.append(str(outdir.joinpath(filename.name.with_suffix('.webp'))))
        return cmd

    @staticmethod
    def backuparchive(archive, filelist, exepath=findexe('7za')):
        if not isinstance(archive, pathlib.Path):
            archive = pathlib.Path(archive)
        cmd = shlex.split("{} a {}".format(exepath, archive))
        cmd.extend(filelist)
        print(Mood.happy('Archiving source files to {}'.format(archive)))
        Program.runprogram(cmd)
