import platform
import collections
import json
import pathlib
import shlex
import shutil
import pwd
import sys
import hashlib

try:
    from natsort import humansorted
except ImportError:
    pass

from termcolor import colored

class Color:
    def mood(self, currentmood):
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
    def __init__(self):
        self.colors=Color()

    def flatten(self, lst):
        for elem in lst:
            if isinstance(elem, (tuple, list, collections.deque)):
                for i in flatten(elem):
                    yield i
            else:
                yield elem

    def genjson(self, filename, dictionary, printdata=False):
        jsonpath=pathlib.Path(filename).resolve()
    #    print(dictionary)
            if not isinstance(dictionary, (dict, collections.ChainMap, collections.OrderedDict, collections.defaultdict)):
                print("{} Second argument must be a dictionary.".format(self.colors.mood("sad")))
                raise TypeError
        if not printdata:
            if jsonpath.exists():
                print("{} Backing up {} to {}".format(self.colors.mood("happy"), str(jsonpath), str(jsonpath).replace(".json", ".json.bak")))
                with open(str(jsonpath)) as orig, open(str(jsonpath).replace(".json", ".json.bak"), "w") as backup:
                    backup.write(orig.read())

            with open(str(jsonpath), "w") as dest:
                print("{} Writing values to JSON file: {}".format(self.colors.mood("happy"), str(jsonpath)))
                dest.write(json.dumps(dictionary, sort_keys=True, indent="\t"))
        else:
            print(json.dumps(dictionary, sort_keys=True, indent="\t"))

    def is_python_version(self, query):
        if not isinstance(query, (tuple, list, collections.deque)):
            print("{} Value must be a tuple or a list.".format(self.colors.mood("sad")))
            raise TypeError

        if isinstance(query, (list, collections.deque)):
            query=tuple(query)

        if sys.version_info[:len(query)] >= query:
            return True
        else:
            return False

    def is_privileged(self, privuser="root"):
        if isinstance(privuser, str):
            user=pwd.getpwnam(privuser)
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
        hasher=hashlib.sha256()
        filepath=pathlib.Path(filename).resolve()
        with open(str(filepath), "rb", 200000000) as afile:
            hasher.update(afile.read())
        return hasher.hexdigest()

    def prettylist(text, quotes=False, sep=", "):
        if quotes:
            return sep.join(repr(e) for e in text)
        else:
            return sep.join(str(e) for e in text)

class Program(Util, Color):
    def __init__(self):
        self.colors=Color()

    def runprogram(self, program, verify=True, use_sudo=False, user="root", stdinput=None, stdoutput=None, stderror=None, environment=None, workdir=None):
        if isinstance(program, collections.deque):
            command=program
        elif isinstance(program, (tuple, list)):
            command=collections.deque(program)
        elif isinstance(program, str):
            command=collections.deque(shlex.split(program))
        else:
            print("{} program must be in the form of a string, tuple, list or deque".format(self.colors.mood("sad")))
            raise TypeError

        if use_sudo and not isinstance(user, (str, int)):
            print("{} User must be a string or integer.".format(self.colors.mood("sad")))
            raise TypeError

        if use_sudo and isinstance(user, int):
            uid=pwd.getpwuid(user)
            user=uid.pw_name

        if use_sudo:
            """command.extendleft([user, "-u", "sudo"]) #has to be backwards because each entry is prepended to the beginning of the list in the state its at when it gets to that point in the list."""
            sudo=collections.deque(["sudo", "-u", user])
            command=sudo+command
        if Util.is_python_version((3,5,0)):
            subprocess.run(command, input=stdinput, stdout=stdoutput, stderr=stderror, env=environment, check=verify, cwd=workdir)
        else:
            if verify:
                subprocess.check_call(command, stdin=stdinput, stdout=stdoutput, stderr=stderror, env=environment, cwd=workdir)
            else:
                subprocess.call(command, stdin=stdinput, stdout=stdoutput, stderr=stderror, env=environment, cwd=workdir)

    def returninfo(self, source, string=True, stdinput=None):
        if isinstance(source, str):
            source=shlex.split(source)
        data=subprocess.Popen(source, stdin=stdinput, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        if string:
            return data.communicate()[0].decode("utf-8")
        else:
            return data.communicate()[0]
