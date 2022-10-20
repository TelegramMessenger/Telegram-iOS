"""
Digress comparers.
"""

from digress.errors import ComparisonError

import os
from itertools import imap, izip

def compare_direct(value_a, value_b):
    if value_a != value_b:
        raise ComparisonError("%s is not %s" % (value_a, value_b))

def compare_pass(value_a, value_b):
    """
    Always true, as long as the test is passed.
    """

def compare_tolerance(tolerance):
    def _compare_tolerance(value_a, value_b):
        if abs(value_a - value_b) > tolerance:
            raise ComparisonError("%s is not %s (tolerance: %s)" % (
                value_a,
                value_b,
                tolerance
            ))
    return _compare_tolerance

def compare_files(file_a, file_b):
    size_a = os.path.getsize(file_a)
    size_b = os.path.getsize(file_b)

    print file_a, file_b

    if size_a != size_b:
        raise ComparisonError("%s is not the same size as %s" % (
            file_a,
            file_b
        ))

    BUFFER_SIZE = 8196

    offset = 0

    with open(file_a) as f_a:
        with open(file_b) as f_b:
            for chunk_a, chunk_b in izip(
                imap(
                    lambda i: f_a.read(BUFFER_SIZE),
                    xrange(size_a // BUFFER_SIZE + 1)
                ),
                imap(
                    lambda i: f_b.read(BUFFER_SIZE),
                    xrange(size_b // BUFFER_SIZE + 1)
                )
            ):
                chunk_size = len(chunk_a)

                if chunk_a != chunk_b:
                    for i in xrange(chunk_size):
                        if chunk_a[i] != chunk_b[i]:
                            raise ComparisonError("%s differs from %s at offset %d" % (
                                file_a,
                                file_b,
                                offset + i
                            ))

                offset += chunk_size
