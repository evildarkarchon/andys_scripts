import json
import pathlib
import collections

from andy.colors import Color

colors=Color()

def genjson(filename, dictionary, printdata=False):
    jsonpath=pathlib.Path(filename).resolve()
#    print(dictionary)

    if not isinstance(dictionary, (dict, collections.ChainMap, collections.OrderedDict, collections.defaultdict)):
        print("{} Second argument must be a dictionary.".format(colors.mood("sad")))
        raise TypeError
    if not printdata:
        if jsonpath.exists():
            print("{} Backing up {} to {}".format(colors.mood("happy"), str(jsonpath), str(jsonpath).replace(".json", ".json.bak")))
            with open(str(jsonpath)) as orig, open(str(jsonpath).replace(".json", ".json.bak"), "w") as backup:
                backup.write(orig.read())

        with open(str(jsonpath), "w") as dest:
            print("{} Writing values to JSON file: {}".format(colors.mood("happy"), str(jsonpath)))
            dest.write(json.dumps(dictionary, sort_keys=True, indent="\t"))
    else:
        print(json.dumps(dictionary, sort_keys=True, indent="\t"))
