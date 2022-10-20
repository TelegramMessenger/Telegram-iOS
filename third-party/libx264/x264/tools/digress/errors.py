"""
Digress errors.
"""

class DigressError(Exception):
    """
    Digress error base class.
    """

class NoSuchTestError(DigressError):
    """
    Raised when no such test exists.
    """

class DisabledTestError(DigressError):
    """
    Test is disabled.
    """

class SkippedTestError(DigressError):
    """
    Test is marked as skipped.
    """

class DisabledCaseError(DigressError):
    """
    Case is marked as disabled.
    """

class SkippedCaseError(DigressError):
    """
    Case is marked as skipped.
    """

class FailedTestError(DigressError):
    """
    Test failed.
    """

class ComparisonError(DigressError):
    """
    Comparison failed.
    """

class IncomparableError(DigressError):
    """
    Values cannot be compared.
    """

class AlreadyRunError(DigressError):
    """
    Test/case has already been run.
    """

class SCMError(DigressError):
    """
    Error occurred in SCM.
    """
    def __init__(self, message):
        self.message = message.replace("\n", " ")

    def __str__(self):
        return self.message
