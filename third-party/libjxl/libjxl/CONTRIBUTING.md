# Contributing to libjxl

## Contributing with bug reports

For security-related issues please see [SECURITY.md](SECURITY.md).

We welcome suggestions, feature requests and bug reports. Before opening a new
issue please take a look if there is already an existing one in the following
link:

 *  https://github.com/libjxl/libjxl/issues

## Contributing with patches and Pull Requests

We'd love to accept your contributions to the JPEG XL Project. Please read
through this section before sending a Pull Request.

### Contributor License Agreements

Our project is open source under the terms outlined in the [LICENSE](LICENSE)
and [PATENTS](PATENTS) files. Before we can accept your contributions, even for
small changes, there are just a few small guidelines you need to follow:

Please fill out either the individual or corporate Contributor License Agreement
(CLA) with Google. JPEG XL Project is an an effort by multiple individuals and
companies, including the initial contributors Cloudinary and Google, but Google
is the legal entity in charge of receiving these CLA and relicensing this
software:

  * If you are an individual writing original source code and you're sure you
  own the intellectual property, then you'll need to sign an [individual
  CLA](https://code.google.com/legal/individual-cla-v1.0.html).

  * If you work for a company that wants to allow you to contribute your work,
  then you'll need to sign a [corporate
  CLA](https://code.google.com/legal/corporate-cla-v1.0.html).

Follow either of the two links above to access the appropriate CLA and
instructions for how to sign and return it. Once we receive it, we'll be able
to accept your pull requests.

***NOTE***: Only original source code from you and other people that have signed
the CLA can be accepted into the main repository.

### License

Contributions are licensed under the project's [LICENSE](LICENSE). Each new
file must include the following header when possible, with comment style adapted
to the language as needed:

```
// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
```

### Code Reviews

All submissions, including submissions by project members, require review. We
use GitHub pull requests for this purpose. Consult
[GitHub Help](https://help.github.com/articles/about-pull-requests/) for more
information on using pull requests.

### Contribution philosophy

  * Prefer small changes, even if they don't implement a complete feature. Small
  changes are easier to review and can be submitted faster. Think about what's
  the smallest unit you can send that makes sense to review and submit in
  isolation. For example, new modules that are not yet used by the tools but
  have their own unittests are ok. If you have unrelated changes that
  you discovered while working on something else, please send them in a
  different Pull Request. If your are refactoring code and changing
  functionality try to send the refactor first without any change in
  functionality. Reviewers may ask you to split a Pull Request and it is
  easier to create a smaller change from the beginning.

  * Describe your commits. Add a meaningful description to your commit message, explain what you are changing if it is not trivially obvious, but more importantly explain *why* you are making those changes. For example "Fix
  build" is not a good commit message, describe what build and if it makes sense
  why is this fixing it or why was it failing without this. It is very likely
  that people far in the future without any context you have right now will be
  looking at your commit trying to figure out why was the change introduced. If
  related to an issue in this or another repository include a link to it.

  * Code Style: We follow the [Google C++ Coding
  Style](https://google.github.io/styleguide/cppguide.html). A
  [clang-format](https://clang.llvm.org/docs/ClangFormat.html) configuration
  file is available to automatically format your code, you can invoke it with
  the `./ci.sh lint` helper tool.

  * Testing: Test your change and explain in the commit message *how* your
  commit was tested. For example adding unittests or in some cases just testing
  with the existing ones is enough. In any case, mention what testing was
  performed so reviewers can evaluate whether that's enough testing. In many
  cases, testing that the Continuous Integration workflow passes is enough.

  * Make one commit per Pull Request / review, unless there's a good reason not
  to. If you have multiple changes send multiple Pull Requests and each one can
  have its own review.

  * When addressing comments from reviewers prefer to squash or fixup your
  edits and force-push your commit. When merging changes into the repository we
  don't want to include the history of code review back and forth changes or
  typos. Reviewers can click on the "force-pushed" automatic comment on a Pull
  Request to see the changes between versions. We use "Rebase and merge" policy
  to keep a linear git history which is easier to reason about.

  * Your change must pass the build and test workflows. There's a `ci.sh` script
  to help building and testing these configurations. See [building and
  testing](doc/building_and_testing.md) for more details.

### Contributing checklist.

  * Sign the CLA (only needed once per user, see above).

  * AUTHORS: If this is your first contribution, add your name or your
  company name to the [AUTHORS](AUTHORS) file for copyright tracking purposes.

  * Style guide. Check `./ci.sh lint`.

  * Meaningful commit description: What and *why*, links to issues, testing
  procedure.

  * Squashed multiple edits into a single commit.

  * Upload your changes to your fork and [create a Pull
  Request](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request).

# Community Guidelines

This project follows [Google's Open Source Community
Guidelines](https://opensource.google.com/conduct/).
