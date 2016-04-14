import hashlib
import pathlib

def hashfile(filename):
    blocksize = 65536
    hasher = hashlib.sha256()
    filepath=pathlib.Path(filename).resolve()
    with open(str(filepath), 'rb') as afile:
        buf = afile.read(blocksize)
        while len(buf) > 0:
            hasher.update(buf)
            buf = afile.read(blocksize)
#        hasher.update(afile.read())
    return hasher.hexdigest()
