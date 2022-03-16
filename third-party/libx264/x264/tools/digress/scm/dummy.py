"""
Dummy SCM backend for Digress.
"""

from random import random

def checkout(revision):
    """
    Checkout a revision.
    """
    pass

def current_rev():
    """
    Get the current revision
    """
    return str(random())

def revisions(rev_a, rev_b):
    """
    Get a list of revisions from one to another.
    """
    pass

def stash():
    """
    Stash the repository.
    """
    pass

def unstash():
    """
    Unstash the repository.
    """
    pass

def bisect(command, revision):
    """
    Perform a bisection.
    """
    raise NotImplementedError("dummy SCM backend does not support bisection")
