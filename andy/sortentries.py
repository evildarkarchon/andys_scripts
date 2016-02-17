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
        if type(text) in (str,):
            text=prettylist(text, sep=' ').split()
            return humansorted(text.split())
        if type(text) in (tuple, list):
            return humansorted(text)
        else:
            print("{} Argument must be a string, tuple, or list.".format(colors.mood("sad")))
    else:
        if type(text) in (str,):
            text=prettylist(text, sep=' ').split()
            return sorted(text.split(), key=str.lower)
        elif type(text) in (tuple, list):
            return sorted(text, key=str.lower)
        else:
            print("{} Argument must be a string, tuple, or list.".format(colors.mood("sad")))
            raise ValueError
