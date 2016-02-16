try:
    from natsort import humansorted
    natsortpresent=True
except ImportError:
    natsortpresent=False
    pass

from andy.colors import Color

colors=Color()

def sortentries(text):
    if natsortpresent:
        return humansorted(text)
    else:
        if type(text) in (str,):
            return sorted(text.split(), key=str.lower)
        elif type(text) in (tuple,):
            list(text)
            return sorted(text, key=str.lower)
        elif type(text) in (list,):
            return sorted(text, key=str.lower)
        else:
            print("{} Argument must be a string, tuple, or list".format(colors.mood("sad")))
            raise ValueError
