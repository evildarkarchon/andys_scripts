import collections


def namedtuplefromdict(srcdict, name, params):
    if not isinstance(name, str):
        raise TypeError("name must be a string.")
    if not isinstance(params, (list, tuple, str)):
        raise TypeError("params must be a list, tuple, or string.")
    if not isinstance(srcdict, dict):
        raise TypeError("srcdict must be a dictionary.")

    nt = collections.namedtuple(name, params)
    return nt(**srcdict)
