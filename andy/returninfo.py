import collections
import subprocess

from andy.colors import Color

colors=Color()

def returninfo(source, string=True, stdinput=None):
    if not isinstance(source, (list, tuple, collections.deque)):
        print("{} Source must be a list, tuple, or deque")
        raise TypeError
    data=subprocess.Popen(source, stdin=stdinput, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if string:
        return data.communicate()[0].decode("utf-8")
    else:
        return data.communicate()[0]
