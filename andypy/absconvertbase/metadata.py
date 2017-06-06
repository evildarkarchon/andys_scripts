from ..videoinfodb import VideoInfo # pylint: disable=unused-import

from .base import ABSConvertBase

class ABSMetadata(ABSConvertBase):
    def __init__(self, **kwargs):
        super().__init__(self, kwargs)

    def parse_metadata(self):
        for filename in self.cmdline["files"]:
            _data = self.session.query(VideoInfo).filter(VideoInfo.filename == filename).one()

            if self.cmdline["video_bitrate"]:
                self.metadata[filename]["video_bitrate"] = self.cmdline["video_bitrate"]
            elif _data.type_0 == "video":
                self.metadata[filename]["video_bitrate"] = _data.bitrate_0_raw
            elif _data.type_1 == "video":
                self.metadata[filename]["video_bitrate"] = _data.bitrate_1_raw

            if self.cmdline["audio_bitrate"]:
                self.metadata[filename]["audio_bitrate"] = self.cmdline["audio_bitrate"]
            elif _data.type_0 == "audio":
                self.metadata[filename]["audio_bitrate"] = _data.bitrate_0_raw
            elif _data.type_1 == "audio":
                self.metadata[filename]["audio_bitrate"] = _data.bitrate_1_raw

            if self.cmdline["frame_rate"]:
                self.metadata[filename]["frame_rate"] = self.cmdline["frame_rate"]
            else:
                self.metadata[filename]["frame_rate"] = _data.frame_rate
