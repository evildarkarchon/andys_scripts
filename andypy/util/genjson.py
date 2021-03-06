import json
import pathlib

from ..mood2 import Mood


def genjson(dictionary, filename=None, printdata=False, indentjson=True):
    """Convenience function to take a dictionary, convert it to json, and either write it to a file or print it out.

    dictionary is the dictionary to convert to json.

    filename is the name of the file to write the json to, mandatory if printdata is False.

    If printdata is True it will print the resulting json to stdout instead of writing it to a file.

    If indentjson is True, it will insert tabs in the resulting json (this is the default mode), otherwise, it will output a sorted version of the raw json."""

    if not isinstance(filename, (str, pathlib.Path)) and printdata is False:
        raise TypeError("File name was not specified and printdata mode is disabled.")
    if isinstance(filename, str):
        filename = pathlib.Path(filename)

    if filename.exists():
        filename = filename.resolve()

    if not isinstance(dictionary, dict):
        raise TypeError("First argument must be a dictionary.")
    if printdata:
        if indentjson:
            print(json.dumps(dictionary, sort_keys=True, indent="\t"))
        else:
            print(json.dumps(dictionary, sort_keys=True))
    else:
        if filename.exists():
            print(Mood.happy("Backing up {} to {}".format(str(filename), str(filename).replace(".json", ".json.bak"))))
            with open(str(filename)) as orig, open(str(filename).replace(".json", ".json.bak"), "w") as backup:
                backup.write(orig.read())

        with open(str(filename), "w") as dest:
            print(Mood.happy("Writing values to JSON file: {}".format(str(filename))))
            if indentjson:
                dest.write(json.dumps(dictionary, sort_keys=True, indent="\t"))
            else:
                dest.write(json.dumps(dictionary, sort_keys=True))
