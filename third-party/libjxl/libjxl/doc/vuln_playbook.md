# Security Vulnerabilities Playbook

## Reporting security bugs

Report security bugs by emailing libjxl-security@google.com.

Don't open a GitHub issue, don't discuss it public forums like Discord and don't
send a Pull Request if you think you have found a security bug.

## Overview

This document outlines the guidelines followed by the project when handling
security bugs, their fixes, disclosure and coordination with security
researchers. For more context about this guide, read the [coordinated
vulnerability disclosure
guidelines](https://github.com/google/oss-vulnerability-guide/blob/main/guide.md)
from Google Open Source Programs Office.

The main target audience of this guide is the coordinator from the libjxl
Vulnerability Management Team (VMT) handling the requests, however it is useful
for other people to understand what to expect from this process.

Members of the VMT monitor the reports received by email and will coordinate
for these to be addressed. This doesn't mean that said member would fix the bug,
but their responsibility is to make sure it is handled properly according to
this guide.

## Life of security bug

The Coordinator from VMT will make sure that the following steps are taken.

1. Acknowledge the bug report.

Our policy mandates a maximum of **3 business days** to respond to bug reports
in the given email, but you should respond as soon as possible and keep a fluid
communication with the reporter, who has spent some time looking at the issue.

2. Determine if the bug is a security bug covered by our policy.

Not all bugs are security bugs, and not all security bugs are covered by this
vulnerability disclosure policy. See the [What's a Security bug] section below.

3. Determine the affected versions.

Often new bugs on stable projects are found on new features or because of those
new features, so only the most recent versions are affected. It is important to
determine both what older versions are affected, so users running those older
versions can patch or update the software, and also what older versions are
*not* affected. It is possible that stable distributions ship older versions
that didn't contain the bug and therefore don't need to patch the code. Often
maintainers of package distributions need to patch older versions instead of
updating due to incompatibilities with newer ones and they need to understand
what's the vulnerable code.

Security bugs that have already been fixed in `main` or in already released code
but not disclosed as a vulnerability, for example if fixed as a result of a
refactor, should be treated like any other security bug in this policy and
disclosed indicating the range of older affected versions (expect for versions
before 0.5, see below). In such case a new release would likely not be needed if
one already exists, but stable distributions may be still using those version
and need to be aware of the issue and fix.

If no released version is affected by the bug, for example because it was only
introduced in the `main` branch but not yet released, then no vulnerability
disclosure is needed.

Note: Versions before 0.5 are not covered by the security policy. Those versions
have multiple security issues and should not be used anyway.

4. Communicate with the reporter

Communicate the decision to the reporter.

If the bug was not considered a security bug or not covered by this policy,
explain why and direct the reporter to open a public [issue in
GitHub](https://github.com/libjxl/libjxl/issues) or open one on their behalf.
You don't need to follow the rest of the guide in this case.

If the bug *is* a covered security bug then follow the rest of this guide.

Ask the reporter how they want to be credited in the disclosure: name and
company affiliation if any. Security researchers often value this recognition
and helps them dedicate their time to finding security bugs in our project.

There's no bug bounty (monetary compensation for security bugs) available for
libjxl.

5. Create a Security Advisory draft in GitHub

At this point it was established that the bug is a security issue that requires
a vulnerability disclosure. Start by creating a Security Advisory draft in the
[Security Advisories](https://github.com/libjxl/libjxl/security/advisories) page
in GitHub.

Add a short description of the bug explaining what's the issue and what's the
impact of the issue. Being 'hard' or 'complex' to exploit is not a reason to
discard the potential impact. You can update this description later, save it as
a draft in GitHub.

Add the reporter to the security advisory draft if they have a GitHub account,
and add the project members that will be working on a fix for the bug.

Establish the severity of the issue according to the impact and tag the
appropriate Common Weakness Enumeration (CWE) values. This helps classify the
security issues according to their nature.

6. Work on a fix in a private branch

Coordinators can work on the fix themselves, use a proposed fix from the
reporter if there is one, or work with other project members to create one.

Work on a fix for the bug in *private*. Don't publish a Pull Request with the
fix like you normally do, and don't upload the fix to your libjxl fork. If you
ask another project member to work on it, explain them that they should follow
this guide.

7. Request a CVE number

The Common Vulnerabilities and Exposures (CVE) is the system used to disclose
vulnerabilities in software. A CVE number, like CVE-2021-NNNNNN, is a unique
identifier for a given vulnerability. These numbers are assigned by a CVE
Numbering Authority (CNA) with scope on the given project that has the
vulnerability. For libjxl, we use Google's Generic CNA.

For VMT coordinators at Google, file a bug at
[go/cve-request](https://goto.google.com/cve-request) to request a CVE. See
go/vcp-cna for context.

When requesting the CVE include:

 * A description of the problem (example: bug when parsing this field)
 * A description of the impact of the bug (example: OOB read, remote code
   execution, etc)
 * The proposed CWE id(s) determined earlier.
 * List of affected versions.
 * Reporter of the bug and their preferred name/company to include in the
   disclosure.
 * Links to the issues/fixes (if already public), these can be added later, even
   after the CVE is public.
 * The CPE prefix of the affected project (`cpe:2.3:a:libjxl_project:libjxl`)

When in doubt, you can discuss these with the security team while requesting it.

8. File a Security bug in Chromium (if affected).

libjxl project is in charge of updating and maintaining Chromium's libjxl
integration code, this includes updating the libjxl library when needed. While
the regular CVE disclosure process will eventually create a bug to update
Chromium, filing one at this stage speeds up the process.

[go/crbug](https://goto.google.com/crbug), select the "Security Bug" template
and complete the details. This bug will be used to keep track of what versions
of Chromium need backporting. The new bug in Chromium will not be public
initially, but will be made public some time after the issue is fixed.

9. Test the fixes on the intended releases

When disclosing a vulnerability normally two ways to fix it are offered:

 * A patch or set of patches that fix the issue on `main` branch, and
 * A new release that contains the security fix for the user to update to.

New releases that fix the vulnerability should be PATCH releases, that is, a
previous release (like 1.2.3) plus the patches that fix the vulnerability,
becoming a new version (like 1.2.4). See the [release process](release.md) for
details. At least the latest MINOR release branch should have a PATCH release
with the fix, however it might make sense to also backport the fix to older
minor branch releases, depending on long-term support schedule for certain
releases. For example, if many users are still using a particular older version
of the library and updating to a new version requires significant changes (due
to a redesigned API or new unavailable dependencies) it is helpful to provide a
PATCH release there too.

In either case, make sure that you test the fix in all the branches that you
intend to release it to.

The Continuous Integration pipelines don't work on the private forks created by
the Security Advisory, so manual testing of the fix is needed there before
making it public. Don't upload it to your public fork for testing.

10. Coordinate a date for release of the vulnerability disclosure.

Agree with the reporter and security folks from the CNA on a release date. There
is a maximum of 90 day disclosure timeline from the day the bug was reported.

On the disclosure date publish the fixes and tag the new PATCH release with the
fix. You can prepare private drafts of the release for review beforehand to
reduce the workload.

Update Chromium to the new release version (if affected) and work with Chrome
engineers on the required backports.

## What's a Security bug

A security bug is a bug that can potentially be exploited to let an attacker
gain unauthorized access or privileges. For example, gaining code execution in
libjxl decoder by decoding a malicious .jxl file is a security but hitting a
`JXL_ASSERT()` is not necessarily one.

The supported use cases to consider in the context of security bugs that require
a vulnerability disclosure are "release" builds. The disclosure is intended for
users of the project, to let them know that there is a security issue and that
they should update or patch it.

Unreleased versions are not relevant in this context. A bug introduced in the
`main` branch that is not yet in any release is not covered by this guide even
if the bug allows a remote code execution. CVEs should have a non-empty list of
affected released versions.

"Developer only" code is also not covered by this policy. In particular, tools
that are not installed by the build, or not installed when packaging `libjxl`
are not covered. For example, a bug in `tone_map` would not affect users since
is a developer-only tool. The rationale behind this is that users of the
released software will not have the developer code. This developer code is in
the same libjxl repository for convenience.

When considering the impact of a bug, "release" mode should be assumed. In
release mode `JXL_ASSERT()` and `JXL_CHECK()` are enabled, but `JXL_DASSERT()`
are not. This means that if a `JXL_DASSERT()` protects an out-of-bounds (OOB)
write, then the impact of a bug hitting the `JXL_DASSERT()` is at least an
OOB write. On the other hand, if a bug ends up hitting a `JXL_CHECK()` instead
of continuing, the only impact is the process abort instead of whatever else is
possible after the `JXL_CHECK()`.

Asserts in `libjxl` *tools* cause the tool process to abort, but don't affect
the caller. Either crashing or returning an error (non-zero exit code) would
have the same effect, so `JXL_ASSERT()` failures in the tools have no security
or functional impact.

Asserts in `libjxl` libraries, meant to be linked into other processes, cause
the caller process to abort, potentially causing a Denial of Service, however,
Denial of Service issues are *not* considered security bugs by this policy.
These are still issues and should be fixed, but they are not security issues.

Out-of-bounds (OOB) reads in process memory are considered security
vulnerabilities. OOB reads may allow an attacker to read other buffers from the
same process that it shouldn't have access to, even a small OOB read can
allow the attacker to read an address in the stack or in the heap, defeating
address space randomization techniques. In combination with other bugs these
can enable or simplify attacks to the process using libjxl. OOB reads don't need
to require a segmentation fault to be a problem, leaking process information in
decoded RGB pixels could be used as part of an exploit in some scenarios.

OOB writes and remote code execution (RCE) are security bugs of at least high
security impact.
