from andy.colors import Color

colors=Color()

def listfilter(lst, fltr):
    if not isinstance(lst, tuple) and not isinstance(lst, list):
        print("{} First argument must be a list or tuple.".format(colors.mood("sad")))
        raise TypeError

    if isinstance(lst, tuple):
        list=list(lst)

    return list(filter((fltr).__ne__, lst))
