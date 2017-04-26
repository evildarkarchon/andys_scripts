import collections
import subprocess
import shlex
import pwd  # pylint: disable = e0401

from .mood import Mood


class Program:
    """Compilation of convenience functions related to running subprocesses."""

    @staticmethod
    def runprogram(program, verify=True, use_sudo=False, user=None, stdinput=None, stdoutput=None,  # pylint: disable=r0913
                   stderror=None, environment=None, workdir=None):
        """Convenience function for running programs.

        program is the program to be run.

        verify specifies whether subprocess.check_call is used in python <3.5 or subprocess.run(check=True) is used in python >=3.5.

        use_sudo specifies whether to run the program using sudo.

        user specifies to sudo what user to run as.

        stdinput is used for any data to be passed to the program through stdin, verify should be off if this is used.

        stdoutput specifies a class to handle standard output, default will output it to normal stdout.

        stderror is the same as stdoutput, but for stderr

        environment takes a dictionary that will be used as the environment for the running program.

        workdir specifies the cwd the program will run in."""

        if isinstance(program, (collections.deque, list)):
            command = program
        elif isinstance(program, tuple):
            command = list(program)
        elif isinstance(program, str):
            command = shlex.split(program)
        else:
            print("{} program must be in the form of a string, tuple, list or deque".format(Mood.sad()))
            raise TypeError

        if use_sudo and not isinstance(user, (str, int)):
            print("{} User must be a string or integer.".format(Mood.sad()))
            raise TypeError

        if use_sudo and isinstance(user, int):
            uid = pwd.getpwuid(user)
            user = uid.pw_name

        if use_sudo:
            """command.extendleft([user, "-u", "sudo"]) #has to be backwards because each entry is prepended to the beginning of the list in the state its at when it gets to that point in the list."""  # pylint: disable=w0105
            sudo = collections.deque(["sudo", "-u", user])
            command = sudo + command
        try:
            subprocess.run(command, input=stdinput, stdout=stdoutput, stderr=stderror, env=environment, check=verify, cwd=workdir)
        except NameError:
            if verify:
                subprocess.check_call(command, stdin=stdinput, stdout=stdoutput, stderr=stderror, env=environment, cwd=workdir)
            else:
                subprocess.call(command, stdin=stdinput, stdout=stdoutput, stderr=stderror, env=environment, cwd=workdir)

    @staticmethod
    def returninfo(source, string=True, encoding="utf-8", stdinput=None):
        """Convenience function for returning the output of a program to the caller.

        source is the program to be run.

        if string is True, it will decode the output using the encoding specified by the encoding argument.

        encoding is the encoding used to decode the output bytes object to a string. (defaults to utf-8).

        stdinput is used for any data to be passed to the program through stdin."""

        data = None

        if isinstance(source, str):
            source = shlex.split(source)
        try:
            data = subprocess.run(source, stdin=stdinput, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=True)
        except NameError:
            data = subprocess.check_output(source, stdin=stdinput, stderr=subprocess.DEVNULL)

        if string:
            return data.decode(encoding)
        else:
            return data
