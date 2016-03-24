import sys
import collections
from andy.colors import Color

colors=Color()

def is_python_version(query):
    if not isinstance(query, (tuple, list, collections.deque)):
        print("{} Value must be a tuple or a list.".format(colors.mood("sad")))
        raise TypeError

    if isinstance(query, (list, collections.deque)):
        query=tuple(query)

    if sys.version_info[:len(query)] >= query:
        return True
    else:
        return False
