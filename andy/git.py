
import pathlib
from collections import deque

from andy.util import Mood, Util, Program


class Git:
    """High level functions for working with git, using my runprogram function.

        directory is the directory to be worked in.

        use_sudo controls whether sudo is used.

        sudo_user tells sudo what user to run as.

        url tells git what url to use when cloning a repository."""

    def __init__(self, directory, use_sudo=None, sudo_user=None, url=None):

        self.path = pathlib.Path(directory).resolve()
        self.directory = str(self.path)
        self.url = url

        def sudocheck():
            if use_sudo not in (True, False, None):
                print("{} use_sudo must be True, False, or None".format(Mood.sad()))
                raise ValueError

            if use_sudo is None:
                print("{} use_sudo variable is unset, reverting to manual detection".format(Mood.neutral()))
                if sudo_user:
                    return Util.is_privileged(privuser=sudo_user), sudo_user
                else:
                    return False, None
            elif use_sudo and sudo_user:
                return use_sudo, sudo_user
            elif use_sudo and not sudo_user:
                return use_sudo, "root"

        sudo = sudocheck()
        self.use_sudo = sudo[0]
        self.sudo_user = sudo[1]

    def clean_lock(self):
        """Cleans any stale lock files (currently only index.lock but more will be added if discovered)"""

        if self.path.joinpath(".git", "index.lock").exists():  # pylint: disable=e1101
            if self.use_sudo:
                Program.runprogram(["rm", str(self.path.joinpath(".git", "index.lock"))], use_sudo=self.use_sudo, user=self.sudo_user)
            else:
                self.path.joinpath(".git", "index.lock").unlink()  # pylint: disable=e1101

    def clone(self):
        """Clones the repository to the directory specified by the class using the url specified by the class."""

        if not self.url:
            print("{} url not defined.".format(Mood.sad()))
            raise ValueError
        Program.runprogram(["git", "clone", self.url, self.directory], use_sudo=self.use_sudo, user=self.sudo_user)

    def gc(self, aggressive=False):
        """Runs git's garbage collection subcommand.

        aggressive controles whether to use aggressive mode, USE SPARINGLY, this is much slower than regular mode."""

        gccmd = deque(["git", "gc"])
        if aggressive:
            gccmd.append("--aggressive")
        Program.runprogram(gccmd, workdir=self.directory, use_sudo=self.use_sudo, user=self.sudo_user)

    def pull(self):
        """Updates the repository in the directory specified by the class."""

        Program.runprogram(["git", "pull"], workdir=self.directory, use_sudo=self.use_sudo, user=self.sudo_user)
