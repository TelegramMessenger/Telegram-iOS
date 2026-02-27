# Security and Vulnerability Policy for libjxl

## TL;DR:

CPE prefix: `cpe:2.3:a:libjxl_project:libjxl`

To report a security issue, please email libjxl-security@google.com.

Include in your email a description of the issue, the steps you took to create
the issue, affected versions, and if known, mitigations for the issue. Our
vulnerability management team will acknowledge receiving your email within 3
working days.

This project follows a 90 day disclosure timeline.

For all other bugs, where there are no security implications about disclosing
the unpatched bug, open a [new issue](https://github.com/libjxl/libjxl/issues)
checking first for existing similar issues. If in doubt about the security
impact of a bug you discovered, email first.

## Policy overview

libjxl's Security Policy is based on the [Google Open Source program
guidelines](https://github.com/google/oss-vulnerability-guide) for coordinated
vulnerability disclosure.

Early versions of `libjxl` had a different security policy that didn't provide
security and vulnerability disclosure support. Versions up to and including
0.3.7 are not covered and won't receive any security advisory.

Only released versions, starting from version 0.5, are covered by this policy.
Development branches, arbitrary commits from `main` branch or even releases with
backported features externally patched on top are not covered. Only those
versions with a release tag in `libjxl`'s repository are covered, starting from
version 0.5.

## What's a "Security bug"

A security bug is a bug that can potentially be exploited to let an attacker
gain unauthorized access or privileges such as disclosing information or
arbitrary code execution. Not all fuzzer-found bugs and not all assert()
failures are considered security bugs in libjxl. For a detailed explanation and
examples see our [Security Vulnerabilities Playbook](doc/vuln_playbook.md).

## What to expect

To report a security issue, please email libjxl-security@google.com with all the
details about the bug you encountered.

 * Include a description of the issue, steps to reproduce, etc. Compiler
   versions, flags, exact version used and even CPU are often relevant given our
   usage of SIMD and run-time dispatch of SIMD instructions.

 * A member of our security team will reply to you within 3 business days. Note
   that business days are different in different countries.

 * We will evaluate the issue and we may require more input from your side to
   reproduce it.

 * If the issue fits in the description of a security bug, we will issue a
   CVE, publish a fix and make a new minor or patch release with it. There is
   a maximum of 90 day disclosure timeline, we ask you to not publish the
   details before the 90 day deadline or the release date (whichever comes
   first).

 * In the case that we publish a CVE we will credit the external researcher who
   reported the issue. When reporting security issues please let us know if you
   need to include specific information while doing so, like for example a
   company affiliation.

Our security team follows the [Security Vulnerabilities
Playbook](doc/vuln_playbook.md). For more details about the process and policies
please take a look at it.
