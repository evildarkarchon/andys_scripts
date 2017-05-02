import pathlib

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.engine.reflection import Inspector
from sqlalchemy.orm import sessionmaker
import sqlalchemy.orm.exc

from schema import VideoInfo, VideoJSON
from ..probe import probe
from ...mood2 import Mood


SQLBase = declarative_base()


class VideoData:

    def __init__(self, db, verbose=False, regen=False, regenjson=False):
        if not pathlib.Path(db).exists():
            pathlib.Path(db).touch()

        self.dbpath = pathlib.Path(db).resolve()
        self.verbose = verbose
        self.dataengine = create_engine("sqlite:///{}".format(self.dbpath))
        self.inspect = Inspector.from_engine(self.dataengine)
        if regen:
            # with self.dataengine.connect() as con:
            #    print("{} Deleting existing videoinfo table.".format(Mood.happy()))
            #    con.execute("DROP TABLE videoinfo")
            #    if regenjson:
            #        print("{} Deleting existing videojson table.".format(Mood.happy()))
            #        con.execute("DROP TABLE videojson")
            #    con.execute('VACUUM')
            print(Mood.happy("Deleting existing videoinfo table."))
            VideoInfo.__table__.drop(self.dataengine)  # pylint: disable=e1101
            if regenjson:
                print(Mood.happy("Deleting existing videojson table."))
                VideoJSON.__table__.drop(self.dataengine)   # pylint: disable=e1101
        print(Mood.happy("Creating database tables."))
        SQLBase.metadata.create_all(self.dataengine)
        if verbose:
            print(Mood.happy("Tables List:\n{}".format(self.inspect.get_table_names())))
            if "videoinfo" in self.inspect.get_table_names():
                print(Mood.happy("Column Names:\n{}".format(self.inspect.get_columns("videoinfo"))))
        sessionbase = sessionmaker(bind=self.dataengine)
        self.session = sessionbase()  # pylint: disable=c0103

    def parse(self, videofile, ffprobe=None, bequiet=False):
        cache = None
        videoname = str(pathlib.Path(videofile).name)
        try:
            cache = self.session.query(VideoJSON).filter(VideoJSON.filename == videoname).one()
            print(Mood.happy("Information found in the cache."))
            # print(cache.json)
        except sqlalchemy.orm.exc.NoResultFound:
            # if self.verbose:
            #    print("{} No entry in the cache.".format(Mood.neutral()))
            print(Mood.neutral("No entry in the cache."))

        if isinstance(cache, VideoJSON):
            return cache.json
        else:
            return probe(videofile, ffprobe, bequiet)
