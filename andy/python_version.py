import sys

from andy.colors import Color

colors=Color()

def is_python_version(query):
    if type(query) not in (tuple, list):
        print("{} Value must be a tuple or a list.".format(colors.mood("sad")))
        raise ValueError

    if type(query) in (list,):
        query=tuple(query)

    if sys.version_info[:len(query)] >= query:
        return True
    else:
        return False
