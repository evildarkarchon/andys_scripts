import json
import pathlib

from andy.colors import Color

colors=Color()

def genjson(filename, dictionary):
    jsonpath=pathlib.Path(filename)

    if not isinstance(dictionary, dict):
        print("{} Second argument must be a dictionary.".format(colors.mood("sad")))
        raise TypeError

    if jsonpath.exists():
        print("{} Backing up {} to {}".format(colors.mood("happy"), filename, filename.replace(".json", ".json.bak")))
        with open(filename) as orig, open(filename.replace(".json", ".json.bak"), "w") as backup:
            backup.write(orig.read())

    with open(jsonfile) as dest:
        print("{} Writing values to JSON file: {}".format(colors.mood("happy"), jsonfile))
        json.dumps(dictionary, sort_keys=True, indent="\t")
