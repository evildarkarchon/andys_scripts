# noqa E111
import collections
import sys
from pkg_resources import parse_version
from ..mood2 import Mood


def is_python_version(query):
    """Helper function to take a tuple of the minimum version of python you are searching for and returning True if its greater than or equal to that version or False if its not.

    It will convert any tuple-convertable types into a tuple for the purposes of evaluation.

    query is a tuple of the minimum version of python that will return True."""

    if not isinstance(query, (tuple, list, collections.deque)):
        # print("{} Value must be a tuple or a list.".format(Mood.sad()))
        print(Mood.sad('Value must be a tuple or a list'))
        raise TypeError

    if isinstance(query, tuple):
        query = list(query)

    query = list(map(str, query))
    query = '.'.join(query)
    query = parse_version(query)
    version = list(map(str, sys.version_info[:4]))
    version = parse_version('.'.join(version))

    return bool(query >= version)
