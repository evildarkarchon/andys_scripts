from andy.colors import Color

colors = Color()


class VarLengthError(Exception):  # This code is a work in progress (may not even keep this name).

    def __init__(self, var, length, message=None):
        self.errorstr = "\n{} {} must have {} entries.".format(colors.mood("sad"), var, length)

    def __str__(self):
        return str(self.errorstr)
