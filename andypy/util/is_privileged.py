import os
import pathlib

def is_privileged(comp):
        """Helper function to check if the current user can access the comp/file specified.

        Directory is the path-like object (or a string that can be turned into one) to evaluate."""

        assert isinstance(comp, (str, pathlib.Path))
        if isinstance(comp, str):
            comp = pathlib.Path(comp)

        if comp and comp.is_dir():
            try:
                test = comp.joinpath('temp').write_text('this is a test')  # pylint: disable=no-member
            except (OSError, PermissionError):
                return False
            else:
                return True
            finally:
                if test.exists():
                    test.delete()
        elif comp and comp.is_file():
            assert isinstance(test, bool)
            try:
                return os.access(comp, os.W_OK)
            except TypeError:
                return os.access(str(comp), os.W_OK)
