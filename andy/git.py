import pathlib
import os

from collections import deque

from andy.runprogram import runprogram
from andy.colors import Color
from andy.privileged import is_privileged

class Git:
    def __init__(self, directory, use_sudo=None, sudo_user="root", url=None):
        self.colors=Color()
        self.path=pathlib.Path(directory).resolve()
        self.directory=str(self.path)
        self.url=url

        if use_sudo not in (True, False, None):
            print("{} use_sudo must be True, False, or None".format(colors.mood("sad")))
            raise ValueError

        if use_sudo is None:
            print("{} use_sudo variable is unset, reverting to manual detection".format(self.colors.mood("neutral")))
            if sudo_user:
                self.use_sudo=is_privileged(privuser=sudo_user)
            else:
                self.use_sudo=False
                self.sudo_user=None
        elif use_sudo and sudo_user:
            self.use_sudo=use_sudo
        elif use_sudo and not sudo_user:
            self.use_sudo=use_sudo
            self.sudo_user="root"

        if sudo_user and use_sudo and not self.sudo_user:
            self.sudo_user=sudo_user
        else:
            self.sudo_user=None

    def clean_lock(self):
        if self.path.joinpath(".git", "index.lock").exists():
            if self.use_sudo:
                runprogram(["rm", str(self.path.joinpath(".git", "index.lock"))], use_sudo=self.use_sudo, user=self.sudo_user)
            else:
                self.path.joinpath(".git", "index.lock").unlink()

    def clone(self):
        if not self.url:
            print("{} url not defined.".format(colors.mood("sad")))
            raise ValueError
        runprogram(["git", "clone", self.url], workdir=self.directory, use_sudo=self.use_sudo, user=self.sudo_user)

    def gc(self, aggressive=False):
        gccmd=deque(["git", "gc"])
        if aggressive:
            gccmd.append("--aggressive")
        runprogram(gccmd, workdir=self.directory, use_sudo=self.use_sudo, user=self.sudo_user)

    def pull(self):
        runprogram(["git", "pull"], workdir=self.directory, use_sudo=self.use_sudo, user=self.sudo_user)
