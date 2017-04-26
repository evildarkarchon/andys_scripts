import collections

try:
    from natsort import humansorted
except ImportError:
    pass


def sortentries(text):
    """Helper function to sort lists, it will use the natsort module's humansorted function if its available.
    Otherwise it will use the builtin sorting function (which is not quite as good).
    It will split strings into lists if that's what's been given to sort.

    text is the text to be sorted."""

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
