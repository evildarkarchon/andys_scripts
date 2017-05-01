import platform

from termcolor import colored


class Mood:

    """Class to replace the old Color class that uses static methods instead of string conditionals.
    Also, because it is using static methods, it no longer requires class instantiation."""

    @staticmethod
    def happy(message):
        """Prints a green star on unix, a generic star on windows."""
        system = platform.system

        if system is not "Windows":
            return "{} {}".format(colored("*", "green"), message)
        else:
            return "* {}".format(message)

    @staticmethod
    def neutral(message):
        """Prints a yellow star on unix, a generic star on windows."""
        system = platform.system

        if system is not "Windows":
            return "{} {}".format(colored("*", "yellow"), message)
        else:
            return "* {}".format(message)

    @staticmethod
    def sad(message):
        """Prints a red star on unix, a generic star on windows."""
        system = platform.system

        if system is not "Windows":
            return "{} {}".format(colored("*", "red"), message)
        else:
            return "* {}".format(message)
