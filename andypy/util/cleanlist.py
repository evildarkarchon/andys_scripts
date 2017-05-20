import itertools

from ..mood2 import Mood


def cleanlist(iterable, flatten=True, dedup=True, clean=True, debug=False, quiet=False):
    out = iterable
    if clean and not debug:
        try:
            out = [x for x in iterable if x is not None]
        except TypeError:
            if not quiet:
                print(Mood.neutral('Clean failed due to a type error, skipping.'))
    elif clean and debug:
        out = [x for x in iterable if x is not None]

    if dedup and not debug:
        try:
            out = list(dict.fromkeys(out))
        except TypeError:
            if not quiet:
                print(Mood.neutral('De-Dup failed due to a type error, skipping.'))
    elif clean and debug:
        out = list(dict.fromkeys(out))

    if flatten and not debug:
        try:
            out = list(itertools.chain.from_iterable(out))
        except TypeError:
            if not quiet:
                print(Mood.neutral('Flatten failed due to a type error, skipping.'))
    elif flatten and debug:
        out = list(itertools.chain.from_iterable(out))

    '''if not isinstance(out, list):
        return list(out)
    else:
        return out'''
    return out
