import hashlib
import pathlib

def hashfile(filename):
    hasher=hashlib.sha256()
    filepath=pathlib.Path(filename).resolve()
    with open(str(filepath), "rb", 200000000) as afile:
        hasher.update(afile.read())
    return hasher.hexdigest()
