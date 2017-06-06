# import itertools
import collections


from ..mood2 import Mood

def flattenlist(l):
    for el in l:
        if isinstance(el, collections.Iterable) and not isinstance(el, (str, bytes)):
            yield from flattenlist(el)
        else:
            yield el

def cleanlist(iterable, flatten=True, dedup=True, clean=True, debug=False, verbose=False):
    """
    iterable is the iterable to be cleaned (usually a list)

    flatten takes any nested lists and makes them into a single list (type errors here usually mean there are no nested lists)

    dedup attempts to remove any duplicate entries from the iterable

    clean removes any None entries from the iterable

    debug disables all exception catching

    quiet messages will not be printed when exceptions are caught (does nothing to uncaught exceptions)
    """
    out = iterable
    if clean:
        try:
            out = [x for x in out if x is not None]
        except TypeError as c:
            if verbose or debug:
                print(Mood.neutral('Clean failed due to a type error, skipping.'))
            if debug:
                print(c)

    if flatten:
        try:
            out = list(flattenlist(out))
        except TypeError as f:
            if verbose or debug:
                print(Mood.neutral('Flatten failed due to a type error, skipping.'))
            if debug:
                print(f)

    if dedup:
        try:
            out = list(dict.fromkeys(out))
        except TypeError as d:
            if verbose or debug:
                print(Mood.neutral('De-Dup failed due to a type error, skipping.'))
            if debug:
                print(d)

    return out
