import collections
try:
    from natsort import humansorted
    natsortpresent=True
except ImportError:
    natsortpresent=False
    print("natsort not found.")
    pass

from andy.colors import Color
from andy.prettylist import prettylist
from andy.flatten import flatten

colors=Color()

def sortentries(text):
    if natsortpresent:
        if isinstance(text, str):
            text=prettylist(text, sep=' ').split()
            return humansorted(text.split())
        elif isinstance(text, (list, collections.deque)):
            return humansorted(text)
        elif isinstance(text, tuple):
            text=list(text)
            return humansorted(text)
        else:
            print("{} Argument must be a string, tuple, or list.".format(colors.mood("sad")))
            raise TypeError
    else:
        if isinstance(text, str):
            text=prettylist(text, sep=' ').split()
            return sorted(text.split(), key=str.lower)
        elif isinstance(text, (list, collections.deque)):
            return sorted(text, key=str.lower)
        elif isinstance(text, tuple):
            text=list(text)
            return sorted(text, key=str.lower)
        else:
            print("{} Argument must be a string, tuple, or list.".format(colors.mood("sad")))
            raise TypeError
