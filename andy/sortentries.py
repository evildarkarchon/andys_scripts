import collections

from andy.colors import Color
from andy.flatten import flatten
from andy.prettylist import prettylist

try:
    from natsort import humansorted
    natsortpresent=True
except ImportError:
    natsortpresent=False
    print("natsort not found.")
    pass


colors=Color()

def sortentries(text):
    if natsortpresent:
        if isinstance(text, str):
            return humansorted(text.split())
        elif isinstance(text, (list, collections.deque)):
            return humansorted(text)
        else:
            return list(humansorted(text))
    else:
        if isinstance(text, str):
            return sorted(text.split(), key=str.lower)
        elif isinstance(text, (list, collections.deque)):
            return sorted(text, key=str.lower)
        else:
            return list(sorted(text, key=str.lower))
