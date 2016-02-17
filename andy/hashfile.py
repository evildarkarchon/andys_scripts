import hashlib
import pathlib

def hashfile(filename):
    BLOCKSIZE = 65536
    hasher = hashlib.sha512()
    filepath=pathlib.Path(filename)
    with open(str(filepath), 'rb') as afile:
        buf = afile.read(BLOCKSIZE)
        while len(buf) > 0:
            hasher.update(buf)
            buf = afile.read(BLOCKSIZE)
    return hasher.hexdigest()
