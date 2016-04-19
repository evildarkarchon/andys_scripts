import collections

from andy.colors import Color
from andy.flatten import flatten
from andy.prettylist import prettylist
try:
    from natsort import humansorted
except ImportError:
    pass


colors=Color()

def sortentries(text):
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
