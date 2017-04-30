import pathlib
import json
import time

from humanize import naturalsize

from ..string_eval import NumericStringParser


def gendict(filename, jsondata, filehash):
    if not isinstance(jsondata, dict):
        jsondata = json.loads(jsondata)

    yield "filename", pathlib.Path(filename).name
    yield "hash", filehash
    yield "container", jsondata["format"]["format_name"]
    yield "duration", time.strftime("%H:%M:%S", time.gmtime(int(float(jsondata["format"]["duration"]))))
    yield "duration_raw", jsondata["format"]["duration"]
    yield "numstreams", int(jsondata["format"]["nb_streams"])
    yield "codec_0", jsondata["streams"][0]["codec_name"]
    yield "type_0", jsondata["streams"][0]["codec_type"]
    if isinstance(jsondata["streams"][1], dict) and jsondata["streams"][1]["codec_name"]:
        yield "codec_1", jsondata["streams"][1]["codec_name"]
    else:
        yield "codec_1", None

    if isinstance(jsondata["streams"][1], dict) and jsondata["streams"][1]["codec_type"]:
        yield "type_1", jsondata["streams"][1]["codec_type"]
    else:
        yield "type_1", None

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
    yield "bitrate_0", bitrate(0)
    yield "bitrate_1", bitrate(1)
    yield "bitrate_total", naturalsize(jsondata["format"]["bit_rate"]).replace(" MB", "Mbps").replace(" kB", "Kbps")

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

    yield "bitrate_0_raw", bitrate_raw(0)
    yield "bitrate_1_raw", bitrate_raw(1)

    def height():
        try:
            if jsondata["streams"][0]["codec_type"] == "video" and jsondata["streams"][0]["height"]:
                return jsondata["streams"][0]["height"]
            elif isinstance(jsondata["streams"][1], dict) and jsondata["streams"][1]["codec_type"] == "video" and jsondata["streams"][1]["height"]:
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
    yield "height", height()
    yield "width", width()
    yield "frame_rate", frame_rate()
    yield "jsondata", json.dumps(jsondata)
