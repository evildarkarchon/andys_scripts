import os
import pwd  # pylint: disable = e0401

from ..mood2 import Mood


def is_privileged(privuser="root"):
        """Helper function to check if the current effective user is the same as the "privileged" user specified.

        privuser can be either a UID integer or a username string."""

        if isinstance(privuser, str):
            user = pwd.getpwnam(privuser)
            return bool(user.pw_uid == os.geteuid())  # pylint: disable=e1101
        elif isinstance(privuser, int):
            return bool(privuser == os.geteuid())  # pylint: disable=e1101
        else:
            # print("{} User must be specified as a string or an integer".format(Mood.sad()))
            print(Mood.sad("User must be specified as a string or an integer."))
            raise TypeError
