import collections
import pwd  # pwd doesn't exist on windows, so pylint can't import it.  # pylint: disable=import-error
import shlex
import subprocess

from .mood2 import Mood


class Program:
    """Compilation of convenience functions related to running subprocesses."""
    def __init__(self, program, stdinput=None, stdoutput=None, stderror=None, environment=None, workdir=None, use_sudo=False, user=None):
        """
        program is the program to be run.

        use_sudo specifies whether to run the program using sudo.

        user specifies to sudo what user to run as.

        stdinput is used for any data to be passed to the program through stdin, verify should be off if this is used.

        stdoutput specifies a class to handle standard output, default will output it to normal stdout.

        stderror is the same as stdoutput, but for stderr

        environment takes a dictionary that will be used as the environment for the running program.

        workdir specifies the cwd the program will run in."""

        if use_sudo and not isinstance(user, (str, int)):
            print(Mood.sad("User must be a string or integer."))
            raise TypeError

        if use_sudo and isinstance(user, int):
            uid = pwd.getpwuid(user)
            user = uid.pw_name

        if isinstance(program, (collections.deque, list)):
            self.program = program
        elif isinstance(program, tuple):
            self.program = list(program)
        elif isinstance(program, str):
            self.program = shlex.split(program)
        else:
            print(Mood.sad("program must be in the form of a string, tuple, list or deque"))
            raise TypeError
        if use_sudo:
            self.program = shlex.split("sudo -u {}".format(user)) + self.program
        self.stdinput = stdinput
        self.stdoutput = stdoutput
        self.stderror = stderror
        self.environment = environment
        self.workdir = workdir

    def runprogram(self, verify=True, parse_output=False, string=True, encoding='utf-8'):
        """
        Convenience function for running programs.

        verify specifies whether subprocess.check_call is used in python <3.5 or subprocess.run(check=True) is used in python >=3.5.
        """

        try:
            if parse_output:
                if string:
                    return subprocess.run(self.program, stdin=self.stdinput, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=True).stdout.decode(encoding)
                else:
                    return subprocess.run(self.program, stdin=self.stdinput, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=True).stdout
            else:
                subprocess.run(self.program, input=self.stdinput, stdout=self.stdoutput, stderr=self.stderror, env=self.environment, check=verify, cwd=self.workdir)
        except NameError:
            if parse_output:
                if string:
                    return subprocess.check_output(self.program, stdin=self.stdinput, stderr=subprocess.DEVNULL).decode(encoding)
                else:
                    return subprocess.check_output(self.program, stdin=self.stdinput, stderr=subprocess.DEVNULL)
            else:
                if verify:
                    subprocess.check_call(self.program, stdin=self.stdinput, stdout=self.stdoutput, stderr=self.stderror, env=self.environment, cwd=self.workdir)
                else:
                    subprocess.call(self.program, stdin=self.stdinput, stdout=self.stdoutput, stderr=self.stderror, env=self.environment, cwd=self.workdir)
