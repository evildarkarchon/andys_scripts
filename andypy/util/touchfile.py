import pathlib
import shlex

from ..program2 import Program

def touchfile(filename, sudo_user=None):
    touch = Program(shlex.split("touch {}".format(filename)), use_sudo=True, user=sudo_user)
    try:
        pathlib.Path(filename).touch()
    except FileExistsError:
        pass
    except (OSError, PermissionError):
        touch.runprogram()
