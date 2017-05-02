import pathlib
import magic

from ...mood2 import Mood


class FindVideoInfo:  # pylint: disable=R0903

    """This class contains any functions related to locating videoinfo databases.
    Requires filemagic, python-magic will not work, if python-magic is installed, get rid of it and use filemagic instead.
    It's not easy to test for which is which as they use the same module name."""

    @staticmethod
    def find(directory="/data/Private"):
        """Worker function that locates directories with videoinfo database that are under the specified directory.
        Files will be run through filemagic to verify that they actually sqlite databases.
        Just like the genfilelist function in GenVideoInfo, this only works with filemagic,
        if python-magic is installed, get rid of it and use filemagic instead. Its not easy to distinguish
        python-magic from filemagic as they use the same module name.

        directory is the directory to be searched."""

        try:
            test = magic.Magic()
        except NameError:
            print(Mood.sad("Filemagic module not installed."))
            raise
        else:
            del test

        paths = pathlib.Path(directory).rglob("videoinfo.sqlite")
        for filename in paths:
            with magic.Magic() as m, open(str(filename), "rb") as f:
                filetype = m.id_buffer(f.read())
                if "SQLite 3.x database" in filetype:
                    yield str(filename.parent)
