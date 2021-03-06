import datetime


def datediff(timestamp):
    """Front-end Function that will return a timedelta of the supplied timestamp vs. a snapshot of the current time.
    timestamp takes a POSIX timestamp and uses it to create a datetime object for comparison."""
    now = datetime.now()  # pylint: disable=no-member
    then = datetime.fromtimestamp(timestamp)  # pylint: disable=no-member
    return now - then
