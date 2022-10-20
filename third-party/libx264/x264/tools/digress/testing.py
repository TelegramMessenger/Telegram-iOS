"""
Digress testing core.
"""

from digress.errors import SkippedTestError, DisabledTestError, NoSuchTestError, \
                           FailedTestError, AlreadyRunError, SCMError, \
                           ComparisonError
from digress.constants import *
from digress.cli import dispatchable

import inspect
import operator
import os
import json

import textwrap

from shutil import rmtree

from time import time
from functools import wraps

from itertools import izip_longest

from hashlib import sha1

class depends(object):
    """
    Dependency decorator for a test.
    """
    def __init__(self, *test_names):
        self.test_names = test_names

    def __call__(self, func):
        func.digress_depends = self.test_names
        return func

class _skipped(object):
    """
    Internal skipped decorator.
    """
    def __init__(self, reason=""):
        self._reason = reason

    def __call__(self, func):
        @wraps(func)
        def _closure(*args):
            raise SkippedTestError(self._reason)
        return _closure

class disabled(object):
    """
    Disable a test, with reason.
    """
    def __init__(self, reason=""):
        self._reason = reason

    def __call__(self, func):
        @wraps(func)
        def _closure(*args):
            raise DisabledTestError(self._reason)
        return _closure

class comparer(object):
    """
    Set the comparer for a test.
    """
    def __init__(self, comparer_):
        self._comparer = comparer_

    def __call__(self, func):
        func.digress_comparer = self._comparer
        return func

class Fixture(object):
    cases = []
    scm = None

    flush_before = False

    def _skip_case(self, case, depend):
        for name, meth in inspect.getmembers(case):
            if name[:5] == "test_":
                setattr(
                    case,
                    name,
                    _skipped("failed dependency: case %s" % depend)(meth)
                )

    def _run_case(self, case, results):
        if case.__name__ in results:
            raise AlreadyRunError

        for depend in case.depends:
            if depend.__name__ in results and results[depend.__name__]["status"] != CASE_PASS:
                self._skip_case(case, depend.__name__)

            try:
                result = self._run_case(depend, results)
            except AlreadyRunError:
                continue

            if result["status"] != CASE_PASS:
                self._skip_case(case, depend.__name__)

        result = case().run()
        results[case.__name__] = result
        return result

    @dispatchable
    def flush(self, revision=None):
        """
        Flush any cached results. Takes a revision for an optional argument.
        """
        if not revision:
            print "Flushing all cached results...",

            try:
                rmtree(".digress_%s" % self.__class__.__name__)
            except Exception, e:
                print "failed: %s" % e
            else:
                print "done."
        else:
            try:
                rev = self.scm.rev_parse(revision)
            except SCMError, e:
                print e
            else:
                print "Flushing cached results for %s..." % rev,

                try:
                    rmtree(os.path.join(".digress_%s" % self.__class__.__name__, rev))
                except Exception, e:
                    print "failed: %s" % e
                else:
                    print "done."

    @dispatchable
    def run(self, revision=None):
        """
        Run the fixture for a specified revision.

        Takes a revision for an argument.
        """
        oldrev = None
        oldbranch = None
        dirty = False

        try:
            dirty = self.scm.dirty()

            # if the tree is clean, then we don't need to make an exception
            if not dirty and revision is None: revision = "HEAD"

            if revision:
                oldrev = self.scm.current_rev()
                oldbranch = self.scm.current_branch()

                if dirty:
                    self.scm.stash()
                self.scm.checkout(revision)

                rev = self.scm.current_rev()

                self.datastore = os.path.join(".digress_%s" % self.__class__.__name__, rev)

                if os.path.isdir(self.datastore):
                    if self.flush_before:
                        self.flush(rev)
                else:
                    os.makedirs(self.datastore)
            else:
                rev = "(dirty working tree)"
                self.datastore = None

            print "Running fixture %s on revision %s...\n" % (self.__class__.__name__, rev)

            results = {}

            for case in self.cases:
                try:
                    self._run_case(case, results)
                except AlreadyRunError:
                    continue

            total_time = reduce(operator.add, filter(
                None,
                [
                    result["time"] for result in results.values()
                ]
            ), 0)

            overall_status = (
                CASE_FAIL in [ result["status"] for result in results.values() ]
            ) and FIXTURE_FAIL or FIXTURE_PASS

            print "Fixture %s in %.4f.\n" % (
                (overall_status == FIXTURE_PASS) and "passed" or "failed",
                total_time
            )

            return { "cases" : results, "time" : total_time, "status" : overall_status, "revision" : rev }

        finally:
            if oldrev:
                self.scm.checkout(oldrev)
                if oldbranch:
                    self.scm.checkout(oldbranch)
                if dirty:
                    self.scm.unstash()

    @dispatchable
    def bisect(self, good_rev, bad_rev=None):
        """
        Perform a bisection between two revisions.

        First argument is the good revision, second is the bad revision, which
        defaults to the current revision.
        """
        if not bad_rev: bad_rev = self.scm.current_rev()

        dirty = False

        # get a set of results for the good revision
        good_result = self.run(good_rev)

        good_rev = good_result["revision"]

        try:
            dirty = self.scm.dirty()

            if dirty:
                self.scm.stash()

            self.scm.bisect("start")

            self.scm.bisect("bad", bad_rev)
            self.scm.bisect("good", good_rev)

            bisecting = True
            isbad = False

            while bisecting:
                results = self.run(self.scm.current_rev())
                revision = results["revision"]

                # perform comparisons
                # FIXME: this just uses a lot of self.compare
                for case_name, case_result in good_result["cases"].iteritems():
                    case = filter(lambda case: case.__name__ == case_name, self.cases)[0]

                    for test_name, test_result in case_result["tests"].iteritems():
                        test = filter(
                            lambda pair: pair[0] == "test_%s" % test_name,
                            inspect.getmembers(case)
                        )[0][1]

                        other_result = results["cases"][case_name]["tests"][test_name]

                        if other_result["status"] == TEST_FAIL and case_result["status"] != TEST_FAIL:
                            print "Revision %s failed %s.%s." % (revision, case_name, test_name)
                            isbad = True
                            break

                        elif hasattr(test, "digress_comparer"):
                            try:
                                test.digress_comparer(test_result["value"], other_result["value"])
                            except ComparisonError, e:
                                print "%s differs: %s" % (test_name, e)
                                isbad = True
                                break

                if isbad:
                    output = self.scm.bisect("bad", revision)
                    print "Marking revision %s as bad." % revision
                else:
                    output = self.scm.bisect("good", revision)
                    print "Marking revision %s as good." % revision

                if output.split("\n")[0].endswith("is the first bad commit"):
                    print "\nBisection complete.\n"
                    print output
                    bisecting = False

                print ""
        except SCMError, e:
            print e
        finally:
            self.scm.bisect("reset")

            if dirty:
                self.scm.unstash()

    @dispatchable
    def multicompare(self, rev_a=None, rev_b=None, mode="waterfall"):
        """
        Generate a comparison of tests.

        Takes three optional arguments, from which revision, to which revision,
        and the method of display (defaults to vertical "waterfall", also
        accepts "river" for horizontal display)
        """
        if not rev_a: rev_a = self.scm.current_rev()
        if not rev_b: rev_b = self.scm.current_rev()

        revisions = self.scm.revisions(rev_a, rev_b)

        results = []

        for revision in revisions:
            results.append(self.run(revision))

        test_names = reduce(operator.add, [
            [
                (case_name, test_name)
                for
                    test_name, test_result
                in
                    case_result["tests"].iteritems()
            ]
            for
                case_name, case_result
            in
                results[0]["cases"].iteritems()
        ], [])

        MAXLEN = 20

        colfmt = "| %s "

        table = []

        if mode not in ("waterfall", "river"):
            mode = "waterfall"

            print "Unknown multicompare mode specified, defaulting to %s." % mode

        if mode == "waterfall":
            header = [ "Test" ]

            for result in results:
                header.append(result["revision"])

            table.append(header)

            for test_name in test_names:
                row_data = [ ".".join(test_name) ]

                for result in results:
                    test_result = result["cases"][test_name[0]]["tests"][test_name[1]]

                    if test_result["status"] != TEST_PASS:
                        value = "did not pass: %s" % (test_result["value"])
                    else:
                        value = "%s (%.4f)" % (test_result["value"], test_result["time"])

                    row_data.append(value)

                table.append(row_data)

        elif mode == "river":
            header = [ "Revision" ]

            for test_name in test_names:
                header.append(".".join(test_name))

            table.append(header)

            for result in results:
                row_data = [ result["revision"] ]

                for case_name, case_result in result["cases"].iteritems():
                    for test_name, test_result in case_result["tests"].iteritems():

                        if test_result["status"] != TEST_PASS:
                            value = "did not pass: %s" % (test_result["value"])
                        else:
                            value = "%s (%.4f)" % (test_result["value"], test_result["time"])

                        row_data.append(value)

                table.append(row_data)

        breaker = "=" * (len(colfmt % "".center(MAXLEN)) * len(table[0]) + 1)

        print breaker

        for row in table:
            for row_stuff in izip_longest(*[
                textwrap.wrap(col, MAXLEN, break_on_hyphens=False) for col in row
            ], fillvalue=""):
                row_output = ""

                for col in row_stuff:
                    row_output += colfmt % col.ljust(MAXLEN)

                row_output += "|"

                print row_output
            print breaker

    @dispatchable
    def compare(self, rev_a, rev_b=None):
        """
        Compare two revisions directly.

        Takes two arguments, second is optional and implies current revision.
        """
        results_a = self.run(rev_a)
        results_b = self.run(rev_b)

        for case_name, case_result in results_a["cases"].iteritems():
            case = filter(lambda case: case.__name__ == case_name, self.cases)[0]

            header = "Comparison of case %s" % case_name
            print header
            print "=" * len(header)

            for test_name, test_result in case_result["tests"].iteritems():
                test = filter(
                    lambda pair: pair[0] == "test_%s" % test_name,
                    inspect.getmembers(case)
                )[0][1]

                other_result = results_b["cases"][case_name]["tests"][test_name]

                if test_result["status"] != TEST_PASS or other_result["status"] != TEST_PASS:
                    print "%s cannot be compared as one of the revisions have not passed it." % test_name

                elif hasattr(test, "digress_comparer"):
                    try:
                        test.digress_comparer(test_result["value"], other_result["value"])
                    except ComparisonError, e:
                        print "%s differs: %s" % (test_name, e)
                    else:
                        print "%s does not differ." % test_name
                else:
                    print "%s has no comparer and therefore cannot be compared." % test_name

            print ""

    @dispatchable
    def list(self):
        """
        List all available test cases, excluding dependencies.
        """
        print "\nAvailable Test Cases"
        print "===================="
        for case in self.cases:
            print case.__name__

    def register_case(self, case):
        case.fixture = self
        self.cases.append(case)

class Case(object):
    depends = []
    fixture = None

    def _get_test_by_name(self, test_name):
        if not hasattr(self, "test_%s" % test_name):
            raise NoSuchTestError(test_name)
        return getattr(self, "test_%s" % test_name)

    def _run_test(self, test, results):
        test_name = test.__name__[5:]

        if test_name in results:
            raise AlreadyRunError

        if hasattr(test, "digress_depends"):
            for depend in test.digress_depends:
                if depend in results and results[depend]["status"] != TEST_PASS:
                    test = _skipped("failed dependency: %s" % depend)(test)

                dependtest = self._get_test_by_name(depend)

                try:
                    result = self._run_test(dependtest, results)
                except AlreadyRunError:
                    continue

                if result["status"] != TEST_PASS:
                    test = _skipped("failed dependency: %s" % depend)(test)

        start_time = time()
        run_time = None

        print "Running test %s..." % test_name,

        try:
            if not self.datastore:
                # XXX: this smells funny
                raise IOError

            with open(os.path.join(
                self.datastore,
                "%s.json" % sha1(test_name).hexdigest()
            ), "r") as f:
                result = json.load(f)

            value = str(result["value"])

            if result["status"] == TEST_DISABLED:
                status = "disabled"
            elif result["status"] == TEST_SKIPPED:
                status = "skipped"
            elif result["status"] == TEST_FAIL:
                status = "failed"
            elif result["status"] == TEST_PASS:
                status = "passed"
                value = "%s (in %.4f)" % (
                    result["value"] or "(no result)",
                    result["time"]
                )
            else:
                status = "???"

            print "%s (cached): %s" % (status, value)
        except IOError:
            try:
                value = test()
            except DisabledTestError, e:
                print "disabled: %s" % e
                status = TEST_DISABLED
                value = str(e)
            except SkippedTestError, e:
                print "skipped: %s" % e
                status = TEST_SKIPPED
                value = str(e)
            except FailedTestError, e:
                print "failed: %s" % e
                status = TEST_FAIL
                value = str(e)
            except Exception, e:
                print "failed with exception: %s" % e
                status = TEST_FAIL
                value = str(e)
            else:
                run_time = time() - start_time
                print "passed: %s (in %.4f)" % (
                    value or "(no result)",
                    run_time
                )
                status = TEST_PASS

            result = { "status" : status, "value" : value, "time" : run_time }

            if self.datastore:
                with open(os.path.join(
                    self.datastore,
                    "%s.json" % sha1(test_name).hexdigest()
                ), "w") as f:
                    json.dump(result, f)

        results[test_name] = result
        return result

    def run(self):
        print "Running case %s..." % self.__class__.__name__

        if self.fixture.datastore:
            self.datastore = os.path.join(
                self.fixture.datastore,
                sha1(self.__class__.__name__).hexdigest()
            )
            if not os.path.isdir(self.datastore):
                os.makedirs(self.datastore)
        else:
            self.datastore = None

        results = {}

        for name, meth in inspect.getmembers(self):
            if name[:5] == "test_":
                try:
                    self._run_test(meth, results)
                except AlreadyRunError:
                    continue

        total_time = reduce(operator.add, filter(
            None, [
                result["time"] for result in results.values()
            ]
        ), 0)

        overall_status = (
            TEST_FAIL in [ result["status"] for result in results.values() ]
        ) and CASE_FAIL or CASE_PASS

        print "Case %s in %.4f.\n" % (
            (overall_status == FIXTURE_PASS) and "passed" or "failed",
            total_time
        )

        return { "tests" : results, "time" : total_time, "status" : overall_status }
