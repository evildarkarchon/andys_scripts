import os
import pathlib  # noqa: F401 pylint: disable=W0611


def resolvepaths(iterator):
    if not isinstance(iterator, (pathlib.Path, str, list, tuple)):
        raise TypeError('Argument must be a Path, String, List, or Tuple')
    if isinstance(iterator, pathlib.Path) and iterator.exists():
        yield iterator.resolve()
    elif isinstance(iterator, str) and os.path.exists(iterator):
        yield pathlib.Path(iterator).resolve()
    elif isinstance(iterator, (list, tuple)):
         for i in iterator:
            if isinstance(i, pathlib.Path) and i.exists():
                yield i.resolve()
