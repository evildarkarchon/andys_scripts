# pylint: disable=line-too-long
import pathlib
import shlex

from .mood2 import Mood
from .program import Program
from .util.is_privileged import is_privileged


class Git:
    """
    High level functions for working with git, using my runprogram function.

    directory is the directory to be worked in.

    use_sudo controls whether sudo is used.

    sudo_user tells sudo what user to run as.

    """

    def __init__(self, directory, use_sudo=None, sudo_user=None):

        self.path = pathlib.Path(directory)
        if self.path.exists():
            self.path = pathlib.Path(self.path.resolve())
        self.directory = str(self.path)

        def sudocheck():
            if not isinstance(use_sudo, (bool, type(None))):
                # print("{} use_sudo must be a bool or None".format(Mood.sad()))
                print(Mood.sad("use_sudo must be a bool or None"))
                raise TypeError

            if use_sudo is None:
                # print("{} use_sudo variable is unset, reverting to manual detection".format(Mood.neutral()))
                print(Mood.neutral("use_sudo variable is unset, reverting to auto-detection"))
                if sudo_user:
                    return is_privileged(directory), sudo_user
                else:
                    return False, None
            elif use_sudo and not sudo_user:
                return use_sudo, "root"
            else:
                return use_sudo, sudo_user

        sudo = sudocheck()
        self.use_sudo = sudo[0]
        self.sudo_user = sudo[1]

    def clean_lock(self):
        """Cleans any stale lock files (currently only index.lock but more will be added if discovered)"""
        lockpath = pathlib.Path(self.path.joinpath(".git/index.lock"))
        if self.use_sudo:
            lockcmd = shlex.split("rm {}".format(str(lockpath)))

        if lockpath.exists():
            if self.use_sudo:
                Program.runprogram(lockcmd, use_sudo=self.use_sudo, user=self.sudo_user)
            else:
                lockpath.unlink()

    def clone(self, url):
        """Clones the repository to the directory specified by the class using the url specified by the class.

        url tells git what url to use when cloning a repository."""
        cmdline = shlex.split("git clone") + [url, self.directory]

        Program.runprogram(cmdline, use_sudo=self.use_sudo, user=self.sudo_user)

    def gc(self, aggressive=False):
        """Runs git's garbage collection subcommand.

        aggressive controles whether to use aggressive mode, USE SPARINGLY, this is much slower than regular mode."""

        gccmd = shlex.split("git gc")
        if aggressive:
            gccmd.append("--aggressive")
        Program.runprogram(gccmd, workdir=self.directory, use_sudo=self.use_sudo, user=self.sudo_user)

    def pull(self):
        """Updates the repository in the directory specified by the class."""

        Program.runprogram(shlex.split("git pull"), workdir=self.directory, use_sudo=self.use_sudo, user=self.sudo_user)
