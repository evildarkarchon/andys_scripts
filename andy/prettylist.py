def prettylist(text, quotes=False, sep=", "):
    if quotes:
        return sep.join(repr(e) for e in text)
    else:
        return sep.join(str(e) for e in text)
