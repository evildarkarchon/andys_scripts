import hashlib
import pathlib

def hashfile(filename):
    BLOCKSIZE = 65536
    hasher = hashlib.sha256()
    filepath=pathlib.Path(filename).resolve()
    with open(str(filepath), 'rb') as afile:
        buf = afile.read(BLOCKSIZE)
        while len(buf) > 0:
            hasher.update(buf)
            buf = afile.read(BLOCKSIZE)
#        hasher.update(afile.read())
    return hasher.hexdigest()
