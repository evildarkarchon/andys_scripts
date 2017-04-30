import pathlib
import magic


def genfilelist(filelist, existinghash=None):
    """Generator function that takes a list of files and yields a filtered list that eliminates any non-video files (based on known mime types or file extensions) and any files that are already in the database.
    It will use the filemagic module if available for matching based on mime type or use a file extension whitelist if filemagic is not detected.
    python-magic WILL NOT WORK and there is no easy way to test for it as it uses the same module name.
    So if python-magic is installed, get rid of it and install filemagic instead."""

    try:
        whitelist = ['video/x-flv', 'video/mp4', 'video/mp2t', 'video/3gpp', 'video/quicktime', 'video/x-msvideo', 'video/x-ms-wmv']
        whitelist += ['video/webm', 'video/x-matroska', 'video/msvideo', 'video/avi', 'application/vnd.rm-realmedia']
        whitelist += ['audio/x-pn-realaudio', 'audio/x-matroska', 'audio/ogg', 'video/ogg', 'audio/vorbis', 'video/theora']
        whitelist += ['video/3gpp2' 'audio/x-wav', 'audio/wave', 'video/dvd', 'video/mpeg', 'application/vnd.rn-realmedia-vbr']
        whitelist += ['audio/vnd.rn-realaudio', 'audio/x-realaudio']

        with magic.Magic(flags=magic.MAGIC_MIME_TYPE) as m:
            for filename in filelist:
                filepath = pathlib.Path(pathlib.Path(filename).resolve())
                if existinghash:
                    if m.id_filename(filename) in whitelist and filepath.is_file() and filepath.name not in existinghash:
                        yield str(filepath)
                elif not existinghash:
                    if m.id_filename(filename) in whitelist and filepath.is_file():
                        yield str(filepath)
    except NameError:
        whitelist = ['.webm', '.mkv', '.flv', '.vob', '.ogg', '.drc', '.avi', '.wmv', '.yuv', '.rm', '.rmvb', '.asf', '.mp4', '.m4v', '.mpg']
        whitelist += ['.mp2', '.mpeg', '.mpe', '.mpv', '.3gp', '.3g2', '.mxf', '.roq', '.nsv', '.f4v', '.wav', '.ra', '.mka']
        for filename in filelist:
            filepath = pathlib.Path(pathlib.Path(filename).resolve())
            if existinghash:
                if filepath.suffix in whitelist and filepath.is_file() and filepath.name not in existinghash:
                    yield str(filepath)
            elif not existinghash:
                if filepath.suffix in whitelist and filepath.is_file():
                    yield str(filepath)
