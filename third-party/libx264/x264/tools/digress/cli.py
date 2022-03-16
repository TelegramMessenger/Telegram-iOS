"""
Digress's CLI interface.
"""

import inspect
import sys
from optparse import OptionParser

import textwrap

from types import MethodType

from digress import __version__ as version

def dispatchable(func):
    """
    Mark a method as dispatchable.
    """
    func.digress_dispatchable = True
    return func

class Dispatcher(object):
    """
    Dispatcher for CLI commands.
    """
    def __init__(self, fixture):
        self.fixture = fixture
        fixture.dispatcher = self

    def _monkey_print_help(self, optparse, *args, **kwargs):
        # monkey patches OptionParser._print_help
        OptionParser.print_help(optparse, *args, **kwargs)

        print >>sys.stderr, "\nAvailable commands:"

        maxlen = max([ len(command_name) for command_name in self.commands ])

        descwidth = 80 - maxlen - 4

        for command_name, command_meth in self.commands.iteritems():
            print >>sys.stderr, "  %s %s\n" % (
                command_name.ljust(maxlen + 1),
                ("\n" + (maxlen + 4) * " ").join(
                    textwrap.wrap(" ".join(filter(
                            None,
                            command_meth.__doc__.strip().replace("\n", " ").split(" ")
                        )),
                        descwidth
                    )
                )
            )

    def _enable_flush(self):
        self.fixture.flush_before = True

    def _populate_parser(self):
        self.commands = self._get_commands()

        self.optparse = OptionParser(
            usage = "usage: %prog [options] command [args]",
            description = "Digress CLI frontend for %s." % self.fixture.__class__.__name__,
            version = "Digress %s" % version
        )

        self.optparse.print_help = MethodType(self._monkey_print_help, self.optparse, OptionParser)

        self.optparse.add_option(
            "-f",
            "--flush",
            action="callback",
            callback=lambda option, opt, value, parser: self._enable_flush(),
            help="flush existing data for a revision before testing"
        )

        self.optparse.add_option(
            "-c",
            "--cases",
            metavar="FOO,BAR",
            action="callback",
            dest="cases",
            type=str,
            callback=lambda option, opt, value, parser: self._select_cases(*value.split(",")),
            help="test cases to run, run with command list to see full list"
        )

    def _select_cases(self, *cases):
        self.fixture.cases = filter(lambda case: case.__name__ in cases, self.fixture.cases)

    def _get_commands(self):
        commands = {}

        for name, member in inspect.getmembers(self.fixture):
            if hasattr(member, "digress_dispatchable"):
                commands[name] = member

        return commands

    def _run_command(self, name, *args):
        if name not in self.commands:
            print >>sys.stderr, "error: %s is not a valid command\n" % name
            self.optparse.print_help()
            return

        command = self.commands[name]

        argspec = inspect.getargspec(command)

        max_arg_len = len(argspec.args) - 1
        min_arg_len = max_arg_len - ((argspec.defaults is not None) and len(argspec.defaults) or 0)

        if len(args) < min_arg_len:
            print >>sys.stderr, "error: %s takes at least %d arguments\n" % (
                name,
                min_arg_len
            )
            print >>sys.stderr, "%s\n" % command.__doc__
            self.optparse.print_help()
            return

        if len(args) > max_arg_len:
            print >>sys.stderr, "error: %s takes at most %d arguments\n" % (
                name,
                max_arg_len
            )
            print >>sys.stderr, "%s\n" % command.__doc__
            self.optparse.print_help()
            return

        command(*args)

    def pre_dispatch(self):
        pass

    def dispatch(self):
        self._populate_parser()

        self.optparse.parse_args()
        self.pre_dispatch()
        args = self.optparse.parse_args()[1] # arguments may require reparsing after pre_dispatch; see test_x264.py

        if len(args) == 0:
            print >>sys.stderr, "error: no command specified\n"
            self.optparse.print_help()
            return

        command = args[0]
        addenda = args[1:]

        self._run_command(command, *addenda)
