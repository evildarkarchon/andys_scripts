import json
import collections
import pathlib

from .. import mood
def genjson(dictionary, filename=None, printdata=False, indentjson=True):
      """Convenience function to take a dictionary, convert it to json, and either write it to a file or print it out.

      dictionary is the dictionary to convert to json.

      filename is the name of the file to write the json to, mandatory if printdata is False.

      If printdata is True it will print the resulting json to stdout instead of writing it to a file.

      If indentjson is True, it will insert tabs in the resulting json (this is the default mode), otherwise, it will output a sorted version of the raw json."""

      if not isinstance(filename, str) and printdata is False:
          print("{} File name was not specified and printdata mode is disabled.")
          raise TypeError

      jsonpath = pathlib.Path(filename)

      if jsonpath.exists():
          jsonpath = jsonpath.resolve()  # pylint: disable=r0204

      if not isinstance(dictionary, (dict, collections.ChainMap, collections.OrderedDict, collections.defaultdict)):
          print("{} First argument must be a dictionary.".format(Mood.sad()))
          raise TypeError
      if printdata:
          if indentjson:
              print(json.dumps(dictionary, sort_keys=True, indent="\t"))
          else:
              print(json.dumps(dictionary, sort_keys=True))
      else:
          if jsonpath.exists():
              print("{} Backing up {} to {}".format(Mood.happy(), str(jsonpath), str(jsonpath).replace(".json", ".json.bak")))
              with open(str(jsonpath)) as orig, open(str(jsonpath).replace(".json", ".json.bak"), "w") as backup:
                  backup.write(orig.read())

          with open(str(jsonpath), "w") as dest:
              print("{} Writing values to JSON file: {}".format(Mood.happy(), str(jsonpath)))
              if indentjson:
                  dest.write(json.dumps(dictionary, sort_keys=True, indent="\t"))
              else:
                  dest.write(json.dumps(dictionary, sort_keys=True))