import pathlib
from collections import deque

from andy.util import Color, Util, Program


class Git:

    def __init__(self, directory, use_sudo=None, sudo_user=None, url=None):
        self.colors = Color()
        self.util = Util()
        self.program = Program()
        self.path = pathlib.Path(directory).resolve()
        self.directory = str(self.path)
        self.url = url

        def sudocheck():
            if use_sudo not in (True, False, None):
                print("{} use_sudo must be True, False, or None".format(self.colors.mood("sad")))
                raise ValueError

            if use_sudo is None:
                print("{} use_sudo variable is unset, reverting to manual detection".format(self.colors.mood("neutral")))
                if sudo_user:
                    return self.util.is_privileged(privuser=sudo_user), sudo_user
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
        if self.path.joinpath(".git", "index.lock").exists():
            if self.use_sudo:
                self.program.runprogram(["rm", str(self.path.joinpath(".git", "index.lock"))], use_sudo=self.use_sudo, user=self.sudo_user)
            else:
                self.path.joinpath(".git", "index.lock").unlink()

    def clone(self):
        if not self.url:
            print("{} url not defined.".format(self.colors.mood("sad")))
            raise ValueError
        self.program.runprogram(["git", "clone", self.url, self.directory], use_sudo=self.use_sudo, user=self.sudo_user)

    def gc(self, aggressive=False):
        gccmd = deque(["git", "gc"])
        if aggressive:
            gccmd.append("--aggressive")
        self.program.runprogram(gccmd, workdir=self.directory, use_sudo=self.use_sudo, user=self.sudo_user)

    def pull(self):
        self.program.runprogram(["git", "pull"], workdir=self.directory, use_sudo=self.use_sudo, user=self.sudo_user)
