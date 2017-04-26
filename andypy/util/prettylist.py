# pylint: disable=w0311
def prettylist(text, quotes=False, sep=", "):
    """Front-end function that takes an iterable and creates a "pretty" list from it.

    This function courtesy of the community at stackoverflow.com

    text is the iterable to be used for making the pretty list.

    quotes sets whether you want each entry to have quotes around them or not.

    sep takes a string that will be used as the separator for the list."""

    if quotes:
        return sep.join(repr(e) for e in text)
    else:
        return sep.join(str(e) for e in text)
