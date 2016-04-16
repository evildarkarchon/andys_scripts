import collections
import subprocess
import shlex

from andy.colors import Color

colors=Color()

def returninfo(source, string=True, stdinput=None):
    if isinstance(source, str):
        source=shlex.split(source)
    data=subprocess.Popen(source, stdin=stdinput, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if string:
        return data.communicate()[0].decode("utf-8")
    else:
        return data.communicate()[0]
