import os
import pathlib  # noqa: F401 pylint: disable=W0611


def resolvepaths(iterator):
    if isinstance(iterator, pathlib.Path) and iterator.exists():
        return list(iterator.resolve())
    elif isinstance(iterator, str) and os.path.exists(iterator):
        return list(pathlib.Path(iterator).resolve())
    else:
        return [x.resolve() for x in iterator if isinstance(x, pathlib.Path) and x.exists()]
