from contextlib import contextmanager


@contextmanager
def sqa_session(basesess):
    try:
        yield basesess
        basesess.commit()
    except:
        basesess.rollback()
        raise
    finally:
        basesess.close()
