import collections
from andy.colors import Color

colors=Color()
deque=collections.deque()

def listfilter(lst, fltr):
    if not isinstance(lst, (tuple, list, collections.deque)):
        print("{} First argument must be a list or tuple.".format(colors.mood("sad")))
        raise TypeError

    if isinstance(lst, tuple):
        list=list(lst)

    return list(filter((fltr).__ne__, lst))
