import collections

def flatten(lst):
    for elem in lst:
        if isinstance(elem, (tuple, list, collections.deque)):
            for i in flatten(elem):
                yield i
        else:
            yield elem
