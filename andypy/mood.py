import platform
from termcolor import colored


class Mood:

    """Class to replace the old Color class that uses static methods instead of string conditionals.
    Also, because it is using static methods, it no longer requires class instantiation."""

    @staticmethod
    def happy():
        """Prints a green star on unix, a generic star on windows."""
        system = platform.system

        if system is not "Windows":
            return colored("*", "green")
        else:
            return "*"

    @staticmethod
    def neutral():
        """Prints a yellow star on unix, a generic star on windows."""
        system = platform.system

        if system is not "Windows":
            return colored("*", "yellow")
        else:
            return "*"

    @staticmethod
    def sad():
        """Prints a red star on unix, a generic star on windows."""
        system = platform.system

        if system is not "Windows":
            return colored("*", "red")
        else:
            return "*"
