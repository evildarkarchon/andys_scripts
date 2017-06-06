# pylint: disable=relative-beyond-top-level
from sqlalchemy import create_engine
from sqlalchemy.engine.reflection import Inspector
from sqlalchemy.orm import sessionmaker

from ..mood2 import Mood

class ABSConvertBase:
    def __init__(self, cmdline=None, **kwargs):
        _vacuum = kwargs  # pylint: disable=unused-variable
        self.config = None
        self.metadata = {}
        self.cmdline = cmdline
        assert isinstance(cmdline, dict)

        if self.cmdline["debug"]:
            self.database = create_engine("sqlite:///{}".format(self.cmdline["database"]), echo=True)
        else:
            self.database = create_engine("sqlite:///{}".format(self.cmdline["database"]))
        sm = sessionmaker(bind=self.database, autoflush=False, autocommit=False)
        self.session = sm()
        inspect = Inspector.from_engine(self.database)

        if self.cmdline["debug"]:
            print(Mood.neutral("Tables List:\n{}".format(inspect.get_table_names())))
            if "videoinfo" in inspect.get_table_names():
                print(Mood.neutral("Column Names:\n{}".format(inspect.get_columns("videoinfo"))))

        self.container = self.cmdline["container"]
