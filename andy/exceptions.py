from andy.colors import Color

colors=Color()

class NoneError(Exception): # This code is a work in progress (may not even keep this name).
    def __init__(self):
        self.errorstr="\n{} Value is set to None when it shouldn't be.".format(colors.mood("sad"))
    def __str__(self):
        return str(self.errorstr)
