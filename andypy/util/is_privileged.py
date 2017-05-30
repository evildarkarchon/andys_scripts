import os
try:
    import pwd  # pylint: disable = e0401
except ImportError:
    pwdimport = False
else:
    pwdimport = True
import pathlib


def is_privileged(privuser=None, directory=None):
        """Helper function to check if the current effective user is the same as the "privileged" user specified.

        privuser can be either a UID integer or a username string."""

        if not directory and isinstance(privuser, str):
            if pwdimport:
                user = pwd.getpwnam(privuser)
                return bool(user.pw_uid == os.geteuid())  # pylint: disable=no-member
            else:
                return None
        elif not directory and isinstance(privuser, int):
            return bool(privuser == os.geteuid())  # pylint: disable=no-member
        elif not directory and not isinstance(privuser, (str, int)):
            return bool(os.geteuid() == 0)  # pylint: disable=no-member


        if directory:
            try:
                test = pathlib.Path(directory).joinpath('temp').write_text('this is a test')  # pylint: disable=no-member
            except (OSError, PermissionError):
                return False
            else:
                return True
            finally:
                if test.exists():
                    test.delete()
