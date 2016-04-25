import pwd
import shlex
import subprocess
from collections import deque

from andy.colors import Color
from andy.python_version import is_python_version

colors=Color()

def runprogram(program, verify=True, use_sudo=False, user="root", stdinput=None, stdoutput=None, stderror=None, environment=None, workdir=None):

    if isinstance(program, (tuple, list)):
        command=deque(program)
    elif isinstance(program, str):
        command=deque(shlex.split(program))
    else:
        print("{} program must be in the form of a string, tuple, or list")

    if use_sudo and not isinstance(user, (str, int)):
        print("{} User must be a string or integer.".format(colors.mood("sad")))
        raise TypeError

    if use_sudo and isinstance(user, int):
        uid=pwd.getpwuid(user)
        user=uid.pw_name

    if use_sudo:
        command.extendleft([user, "-u", "sudo"]) #has to be backwards because each entry is prepended to the beginning of the list in the state its at when it gets to that point in the list.

    if is_python_version((3,5,0)):
        subprocess.run(command, input=stdinput, stdout=stdoutput, stderr=stderror, env=environment, check=verify, cwd=workdir)
    else:
        if verify:
            subprocess.check_call(command, stdin=stdinput, stdout=stdoutput, stderr=stderror, env=environment, cwd=workdir)
        else:
            subprocess.call(command, stdin=stdinput, stdout=stdoutput, stderr=stderror, env=environment, cwd=workdir)
