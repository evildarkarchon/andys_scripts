import os
import pwd

from andy.colors import Color

colors=Color()

def is_privileged(privuser="root"):
    if isinstance(user, str):
        user=pwd.getpwnam(user)
        if user.pw_uid == os.geteuid():
            return True
        else:
            return False
    elif isinstance(user, int):
        if privuser == os.geteuid():
            return True
        else:
            return False
    else:
        print("{} User must be specified as a string or an integer".format(colors.mood("sad")))
        raise TypeError
