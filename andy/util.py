import platform
import collections
import json
import pathlib
import shlex
import pwd
import sys
import hashlib
import os
import subprocess

try:
    from natsort import humansorted
except ImportError:
    pass

from termcolor import colored
from datetime import datetime


class Color:

    def mood(self, currentmood=None):
        """Specifies what color star to print (or generic if not one of the specified three specified "moods")

        currentmood will return a colored star (or a generic star if run on windows or if currentmood is not specified)
        valid moods are "happy", "sad", and "neutral"."""

        if platform.system is "Windows":
            return "*"
        else:
            if currentmood is "happy":
                return colored("*", "green")
            elif currentmood is "neutral":
                return colored("*", "yellow")
            elif currentmood is "sad":
                return colored("*", "red")
            else:
                return "*"


class Util(Color):

    """Compilation class that houses all the convenience functions that I've either made myself or
    have copy/pasted from stackoverflow."""

    def __init__(self):
        self.colors = Color()

    def genjson(self, dictionary, filename=None, printdata=False, indentjson=True):
        """Convenience function to take a dictionary, convert it to json, and either write it to a file or print it out.

        dictionary is the dictionary to convert to json.

        filename is the name of the file to write the json to, mandatory if printdata is False.

        If printdata is True it will print the resulting json to stdout instead of writing it to a file.

        If indentjson is True, it will insert tabs in the resulting json (this is the default mode), otherwise, it will output a sorted version of the raw json."""

        if not isinstance(filename, str) and printdata is False:
            print("{} File name was not specified and printdata mode is disabled.")
            raise TypeError

        jsonpath = pathlib.Path(filename).resolve()
    #    print(dictionary)
        if not isinstance(dictionary, (dict, collections.ChainMap, collections.OrderedDict, collections.defaultdict)):
            print("{} First argument must be a dictionary.".format(self.colors.mood("sad")))
            raise TypeError
        if printdata:
            if indentjson:
                print(json.dumps(dictionary, sort_keys=True, indent="\t"))
            else:
                print(json.dumps(dictionary, sort_keys=True))
        else:
            if jsonpath.exists():
                print("{} Backing up {} to {}".format(self.colors.mood("happy"), str(jsonpath), str(jsonpath).replace(".json", ".json.bak")))
                with open(str(jsonpath)) as orig, open(str(jsonpath).replace(".json", ".json.bak"), "w") as backup:
                    backup.write(orig.read())

            with open(str(jsonpath), "w") as dest:
                print("{} Writing values to JSON file: {}".format(self.colors.mood("happy"), str(jsonpath)))
                if indentjson:
                    dest.write(json.dumps(dictionary, sort_keys=True, indent="\t"))
                else:
                    dest.write(json.dumps(dictionary, sort_keys=True))

    def is_python_version(self, query):
        """Helper function to take a tuple of the minimum version of python you are searching for and returning True if its greater than or equal to that version or False if its not.
        It will convert any tuple-convertable types into a tuple for the purposes of evaluation.

        query is a tuple of the minimum version of python that will return True."""

        if not isinstance(query, (tuple, list, collections.deque)):
            print("{} Value must be a tuple or a list.".format(self.colors.mood("sad")))
            raise TypeError

        if isinstance(query, (list, collections.deque)):
            query = tuple(query)

        if sys.version_info[:len(query)] >= query:
            return True
        else:
            return False

    def is_privileged(self, privuser="root"):
        """Helper function to check if the current effective user is the same as the "privileged" user specified.

        privuser can be either a UID integer or a username string."""

        if isinstance(privuser, str):
            user = pwd.getpwnam(privuser)
            if user.pw_uid == os.geteuid():
                return True
            else:
                return False
        elif isinstance(privuser, int):
            if privuser == os.geteuid():
                return True
            else:
                return False
        else:
            print("{} User must be specified as a string or an integer".format(self.colors.mood("sad")))
            raise TypeError

    def sortentries(self, text):
        """Helper function to sort lists, it will use the natsort module's humansorted function if its available.
        Otherwise it will use the builtin sorting function (which is not quite as good).
        It will split strings into lists if that's what's been given to sort.

        text is the text to be sorted."""

        try:
            if isinstance(text, str):
                return humansorted(text.split())
            elif isinstance(text, (list, collections.deque)):
                return humansorted(text)
            else:
                return list(humansorted(text))
        except NameError:
            if isinstance(text, str):
                return sorted(text.split(), key=str.lower)
            elif isinstance(text, (list, collections.deque)):
                return sorted(text, key=str.lower)
            else:
                return list(sorted(text, key=str.lower))
                pass

    def hashfile(self, filename):
        """Helper function to calculate hashes for files.

        filename is the name of the file to be hashed."""

        hasher = hashlib.sha256()
        filepath = pathlib.Path(filename).resolve()
        with open(str(filepath), "rb", 200000000) as afile:
            hasher.update(afile.read())
        return hasher.hexdigest()

    def prettylist(self, text, quotes=False, sep=", "):
        """Front-end function that takes an iterable and creates a "pretty" list from it.
        
        This function courtesy of the community at stackoverflow.com

        text is the iterable to be used for making the pretty list.

        quotes sets whether you want each entry to have quotes around them or not.

        sep takes a string that will be used as the separator for the list."""

        if quotes:
            return sep.join(repr(e) for e in text)
        else:
            return sep.join(str(e) for e in text)

    def datediff(self, timestamp):
        """Front-end Function that will return a timedelta of the supplied timestamp vs. a snapshot of the current time.

        timestamp takes a POSIX timestamp and uses it to create a datetime object for comparison."""
        now = datetime.now()
        then = datetime.fromtimestamp(timestamp)
        return now - then


class Program(Util, Color):
    """Convenience functions related to running subprocesses."""

    def __init__(self):
        self.colors = Color()
        self.util = Util()

    def runprogram(self, program, verify=True, use_sudo=False, user=None, stdinput=None, stdoutput=None, stderror=None, environment=None, workdir=None):
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

        if isinstance(program, collections.deque):
            command = program
        elif isinstance(program, (tuple, list)):
            command = collections.deque(program)
        elif isinstance(program, str):
            command = collections.deque(shlex.split(program))
        else:
            print("{} program must be in the form of a string, tuple, list or deque".format(self.colors.mood("sad")))
            raise TypeError

        if use_sudo and not isinstance(user, (str, int)):
            print("{} User must be a string or integer.".format(self.colors.mood("sad")))
            raise TypeError

        if use_sudo and isinstance(user, int):
            uid = pwd.getpwuid(user)
            user = uid.pw_name

        if use_sudo:
            """command.extendleft([user, "-u", "sudo"]) #has to be backwards because each entry is prepended to the beginning of the list in the state its at when it gets to that point in the list."""
            sudo = collections.deque(["sudo", "-u", user])
            command = sudo + command
        if self.util.is_python_version((3, 5, 0)):
            subprocess.run(command, input=stdinput, stdout=stdoutput, stderr=stderror, env=environment, check=verify, cwd=workdir)
        else:
            if verify:
                subprocess.check_call(command, stdin=stdinput, stdout=stdoutput, stderr=stderror, env=environment, cwd=workdir)
            else:
                subprocess.call(command, stdin=stdinput, stdout=stdoutput, stderr=stderror, env=environment, cwd=workdir)

    def returninfo(self, source, string=True, stdinput=None):
        """Convenience function for returning the output of a program to the caller.

        source is the program to be run.

        if string is True, it will decode the output using utf-8.

        stdinput is used for any data to be passed to the program through stdin."""

        if isinstance(source, str):
            source = shlex.split(source)
        data = subprocess.Popen(source, stdin=stdinput, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        if string:
            return data.communicate()[0].decode("utf-8")
        else:
            return data.communicate()[0]
