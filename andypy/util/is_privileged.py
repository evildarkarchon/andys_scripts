import os
import pwd  # pylint: disable = e0401
import pathlib


def is_privileged(privuser=None, directory=None):
        """Helper function to check if the current effective user is the same as the "privileged" user specified.

        privuser can be either a UID integer or a username string."""

        if not directory and isinstance(privuser, str):
            user = pwd.getpwnam(privuser)
            return bool(user.pw_uid == os.geteuid())  # pylint: disable=no-member
        elif not directory and isinstance(privuser, int):
            return bool(privuser == os.geteuid())  # pylint: disable=no-member
        elif not directory and not isinstance(privuser, (str, int)):
            return bool(os.geteuid() == 0)  # pylint: disable=no-member

        if directory:
            try:
                test = pathlib.Path(directory).join('temp')  # pylint: disable=no-member
                open(str(test), 'w')
            except (OSError, PermissionError):
                return False
            else:
                if test.exists():
                    test.delete()
                return True
