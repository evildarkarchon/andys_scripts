from sqlalchemy import (Column, Float, Integer,  # pylint: disable=c0412
                        String)
from sqlalchemy.ext.declarative import declarative_base


SQLBase = declarative_base()  # pylint: disable=c0103


class VideoInfo(SQLBase):
    __tablename__ = 'videoinfo'
    id = Column(Integer, primary_key=True)  # pylint: disable=c0103
    filename = Column(String, nullable=False, unique=True)
    duration = Column(String)
    duration_raw = Column(Float)
    numstreams = Column(Integer)
    container = Column(String, nullable=False)
    width = Column(Integer)
    height = Column(Integer)
    frame_rate = Column(Float)
    bitrate_total = Column(String)
    bitrate_0 = Column(String)
    bitrate_0_raw = Column(Integer)
    type_0 = Column(String)
    codec_0 = Column(String)
    bitrate_1 = Column(String)
    bitrate_1_raw = Column(Integer)
    type_1 = Column(String)
    codec_1 = Column(String)
    filehash = Column(String, unique=True, nullable=False)

    def __repr__(self):
        out = "<VideoInfo(filename={}, duration={}, duration_raw={}, ".format(self.filename, self.duration, self.duration_raw)
        out += "numstreams={}, container={}, width={}, height={}, ".format(self.numstreams, self.container, self.width, self.height)
        out += "frame_rate={}, bitrate_total={}, bitrate_0={}, ".format(self.frame_rate, self.bitrate_total, self.bitrate_0)
        out += "bitrate_0_raw={}, type_0={}, codec_0={}, ".format(self.bitrate_0_raw, self.type_0, self.codec_0)
        out += "bitrate_1={}, bitrate_1_raw={}, type_1={}, ".format(self.bitrate_1, self.bitrate_1_raw, self.type_1)
        out += "codec_1={}, filehash={})>".format(self.codec_1, self.filehash)
        return out


class VideoJSON(SQLBase):
    __tablename__ = 'videojson'
    id = Column(Integer, primary_key=True)
    filename = Column(String, nullable=False, unique=True)
    json = Column(String, nullable=False, unique=True)

    def __repr__(self):
        return "<VideoJSON(filename={}, json={})>".format(self.filename, self.json)
