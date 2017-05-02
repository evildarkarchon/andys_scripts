import json
import pathlib
import time

from humanize import naturalsize
from string_eval import NumericStringParser


class Info:

    def __init__(self, filename, jsondata, filehash):
        if not isinstance(jsondata, dict):
            jsondata = json.loads(jsondata)

        self.filename = pathlib.Path(filename).name
        self.hash = filehash
        self.container = jsondata["format"]["format_name"]
        self.duration = time.strftime("%H:%M:%S", time.gmtime(int(float(jsondata["format"]["duration"]))))
        self.duration_raw = jsondata["format"]["duration"]
        self.numstreams = int(jsondata["format"]["nb_streams"])
        self.codec_0 = jsondata["streams"][0]["codec_name"]
        self.type_0 = jsondata["streams"][0]["codec_type"]
        if isinstance(jsondata["streams"][1], dict) and jsondata["streams"][1]["codec_name"]:
            self.codec_1 = jsondata["streams"][1]["codec_name"]
        else:
            self.codec_1 = None

        if isinstance(jsondata["streams"][1], dict) and jsondata["streams"][1]["codec_type"]:
            self.type_1 = jsondata["streams"][1]["codec_type"]
        else:
            self.type_1 = None

        def bitrate(stream):
            if not isinstance(stream, int):
                raise TypeError("Argument must be an integer.")
            try:
                if isinstance(jsondata["streams"][stream], dict):
                    if "tags" in jsondata["streams"][stream] and "bit_rate" not in jsondata["streams"][stream] and "BPS" in jsondata["streams"][stream]["tags"]:
                        return naturalsize(jsondata["streams"][stream]["tags"]["BPS"]).replace(" MB", "Mbps").replace(" kB", "Kbps")
                    elif "bit_rate" in jsondata["streams"][stream]:
                        return naturalsize(jsondata["streams"][stream]["bit_rate"]).replace(" MB", "Mbps").replace(" kB", "Kbps")
                    else:
                        return None
            except (KeyError, IndexError):
                return None
        self.bitrate_0 = bitrate(0)
        self.bitrate_1 = bitrate(1)
        self.bitrate_total = naturalsize(jsondata["format"]["bit_rate"]).replace(" MB", "Mbps").replace(" kB", "Kbps")

        def bitrate_raw(stream):
            if not isinstance(stream, int):
                raise TypeError("Argument must be an integer.")

            try:
                if isinstance(jsondata["streams"][stream], dict):
                    if "tags" in jsondata["streams"][stream] and "bit_rate" not in jsondata["streams"][stream] and "BPS" in jsondata["streams"][stream]["tags"]:
                        return int(jsondata["streams"][stream]["tags"]["BPS"])
                    elif "bit_rate" in jsondata["streams"][stream]:
                        return int(jsondata["streams"][stream]["bit_rate"])
                    else:
                        return None
            except (KeyError, IndexError):
                return None

        self.bitrate_0_raw = bitrate_raw(0)
        self.bitrate_1_raw = bitrate_raw(1)

        def height():
            try:
                if jsondata["streams"][0]["codec_type"] == "video" and jsondata["streams"][0]["height"]:
                    return jsondata["streams"][0]["height"]
                elif isinstance(jsondata["streams"][1], dict) and jsondata["streams"][1]["codec_type"] == "video" and jsondata["streams"][0]["height"]:
                    return jsondata["streams"][1]["height"]
                else:
                    return None
            except (KeyError, IndexError):
                return None

        def width():
            try:
                if jsondata["streams"][0]["codec_type"] == "video" and jsondata["streams"][0]["width"]:
                    return jsondata["streams"][0]["width"]
                elif isinstance(jsondata["streams"][1], dict) and jsondata["streams"][1]["codec_type"] == "video" and jsondata["streams"][1]["width"]:
                    return jsondata["streams"][1]["width"]
            except (KeyError, IndexError):
                return None

        def frame_rate():
            try:
                nsp = NumericStringParser()
                if jsondata["streams"][0]["codec_type"] == "video" and jsondata["streams"][0]["avg_frame_rate"]:
                    return "{0:.2f}".format(float(nsp.eval(jsondata["streams"][0]["avg_frame_rate"])))
                elif isinstance(jsondata["streams"][1], dict) and jsondata["streams"][1]["codec_type"] == "video" and jsondata["streams"][1]["avg_frame_rate"]:
                    return "{0:.2f}".format(float(nsp.eval(jsondata["streams"][1]["avg_frame_rate"])))
                else:
                    return None
            except (KeyError, IndexError):
                return None
        self.height = height()
        self.width = width()
        self.frame_rate = frame_rate()
        self.jsondata = json.dumps(jsondata)

    def __repr__(self):
        out = "<Info(filename={}, hash={}, container={}, duration={}, ".format(self.filename, self.hash, self.container, self.duration)
        out += "duration_raw={}, numstreams={}, codec_0={}, ".format(self.duration_raw, self.numstreams, self.codec_0)
        out += "type_0={}, bitrate_0={}, codec_1={}, ".format(self.type_0, self.bitrate_0, self.codec_1)
        out += "type_1={}, bitrate_1={}, bitrate_total={}, ".format(self.type_1, self.bitrate_1, self.bitrate_total)
        out += "height={}, width={}, frame_rate={}, jsondata={})>".format(self.height, self.width, self.frame_rate, self.jsondata)

        return out
