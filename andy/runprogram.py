import subprocess

from andy.python_version import is_python_version
from andy.colors import Color

colors=Color()

def runprogram(program, verify=True, use_sudo=False, user="root", stdinput=None, stdoutput=None, stderror=None, environment=None):

    if type(program) in (list, tuple):
        command=list(program)
    elif type(program) in (str,):
        command=program.split()
    else:
        print("{} program must be in the form of a string, tuple, or list")

    if use_sudo:
        command.insert(0, "sudo")
        command.insert(1, "-u")
        command.insert(2, user)

    if is_python_version((3,5,0)):
        subprocess.run(command, input=stdinput, stdout=stdoutput, stderr=stderror, env=environment, check=verify)
    else:
        if verify:
            subprocess.check_call(command, stdin=stdinput, stdout=stdoutput, stderr=stderror, env=environment)
        else:
            subprocess.call(command, stdin=stdinput, stdout=stdoutput, stderr=stderror, env=environment)
