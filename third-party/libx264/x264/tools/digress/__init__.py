"""
Automated regression/unit testing suite.
"""

__version__ = '0.2'

def digress(fixture):
    """
    Command-line helper for Digress.
    """
    from digress.cli import Dispatcher
    Dispatcher(fixture).dispatch()
