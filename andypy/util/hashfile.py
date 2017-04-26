import hashlib
import pathlib

def hashfile(filename):
      """Helper function to calculate hashes for files.

      filename is the name of the file to be hashed."""

      hasher = hashlib.sha256()
      filepath = pathlib.Path(filename).resolve()
      with filepath.open("rb", 200000000) as afile:
          hasher.update(afile.read())
      return hasher.hexdigest()
