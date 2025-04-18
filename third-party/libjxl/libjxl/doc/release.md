# libjxl release process

This guide documents the release process for the libjxl project.

libjxl follows the [semantic versioning](https://semver.org/spec/v2.0.0.html)
specification for released versions. Releases are distributed as tags in the git
repository with the semantic version prefixed by the letter "v". For example,
release version "0.3.7" will have a git tag "v0.3.7".

The public API is explicitly defined as C headers in the `lib/include`
directory, normally installed in your include path. All other headers are
internal API and are not covered by the versioning rules.

## Development and release workflow

New code development is performed on the `main` branch of the git repository.
Pre-submit checks enforce minimum build and test requirements for new patches
that balance impact and test latency, but not all checks are performed before
pull requests are merged. Several slower checks only run *after* the code has
been merged to `main`, resulting in some errors being detected hours after the
code is merged or even days after in the case of fuzzer-detected bugs.

Release tags are cut from *release branches*. Each MAJOR.MINOR version has its
own release branch, for example releases `0.7.0`, `0.7.1`, `0.7.2`, ... would
have tags `v0.7.0`, `v0.7.1`, `v0.7.2`, ... on commits from the `v0.7.x` branch.
`v0.7.x` is a branch name, not a tag name, and doesn't represent a released
version since semantic versioning requires that the PATCH is a non-negative
number. Released tags don't each one have their own release branch, all releases
from the same MAJOR.MINOR version will share the same branch. The first commit
after the branch-off points between the main branch and the release branch
should be tagged with the suffix `-snapshot` and the name of the next
MAJOR.MINOR version, in order to get meaningful output for `git describe`.

The main purpose of the release branch is to stabilize the code before a
release. This involves including fixes to existing bugs but **not** including
new features. New features often come with new bugs which take time to fix, so
having a release branch allows us to cherry-pick *bug fixes* from the `main`
branch into the release branch without including the new *features* from `main`.
For this reason it is important to make small commits in `main` and separate bug
fixes from new features.

After the initial minor release (`MAJOR.MINOR.PATCH`, for example `0.5.0`) the
release branch is used to continue to cherry-pick fixes to be included in a
patch release, for example a version `0.5.1` release. Patch fixes are only meant
to fix security bugs or other critical bugs that can't wait until the next major
or minor release.

Release branches *may* continue to be maintained even after the next minor or
major version has been released to support users that can't update to a newer
minor release. In that case, the same process applies to all the maintained
release branches.

A release branch with specific cherry-picks from `main` means that the release
code is actually a version of the code that never existed in the `main` branch,
so it needs to be tested independently. Pre-submit and post-submit tests run on
release branches (branches matching `v*.*.x`) but extra manual checks should be
performed before a release, specially if multiple bug fixes interact with each
other. Take this into account when selecting which commits to include in a
release. The objective is to have a stable version that can be used without
problems for months. Having the latest improvements at the time the release tag
is created is a non-goal.

## Creating a release branch

A new release branch is needed before creating a new major or minor release,
that is, a new release where the MAJOR or MINOR numbers are increased. Patch
releases, where only the PATCH number is increased, reuse the branch from the
previous release of the same MAJOR and MINOR numbers.

The following instructions assume that you followed the recommended [libjxl git
setup](developing_in_github.md) where `origin` points to the upstream
libjxl/libjxl project, otherwise use the name of your upstream remote repository
instead of `origin`.

The release branch is normally created from the latest work in `main` at the
time the branch is created, but it is possible to create the branch from an
older commit if the current `main` is particularly unstable or includes commits
that were not intended to be included in the release. The following example
creates the branch `v0.5.x` from the latest commit in main (`origin/main`), if a
different commit is to be used then replace `origin/main` with the SHA of that
commit. Change the `v0.5.x` branch name to the one you are creating.

```bash
git fetch origin main
git push git@github.com:libjxl/libjxl.git origin/main:refs/heads/v0.5.x
```

Here we use the SSH URL explicitly since you are pushing to the `libjxl/libjxl`
project directly to a branch there. If you followed the guide `origin` will have
the HTTPS URL which wouldn't normally let you push since you wouldn't be
authenticated. The `v*.*.x` branches are [GitHub protected
branches](https://docs.github.com/en/github/administering-a-repository/defining-the-mergeability-of-pull-requests/about-protected-branches)
in our repository, however you can push to a protected branch when *creating* it
but you can't directly push to it after it is created. To include more changes
in the release branch see the "Cherry-picking fixes to a release" section below.

## Creating a merge label

We use GitHub labels in Pull Requests to keep track of the changes that should
be merged into a given release branch. For this purpose create a new label for
each new MAJOR.MINOR release branch called `merge-MAJOR.MINOR`, for example,
`merge-0.5`.

In the [edit labels](https://github.com/libjxl/libjxl/issues/labels) page, click
on "New label" and create the label. Pick your favorite color.

Labels are a GitHub-only concept and are not represented in git. You can add the
label to a Pull Request even after it was merged, whenever it is decided that
the Pull Request should be included in the given release branch. Adding the
label doesn't automatically merge it to the release branch.

## Update the versioning number

The version number (as returned by `JxlDecoderVersion`) in the source code in
`main` must match the semantic versioning of a release. After the release
branch is created the code in `main` will only be included in the next major
or minor release. Right after a release branch update the version targeting the
next release. Artifacts from `main` should include the new (unreleased) version,
so it is important to update it. For example, after the `v0.5.x` branch is
created from main, you should update the version on `main` to `0.6.0`.

To help update it, run this helper command (in a Debian-based system):

```bash
./ci.sh bump_version 0.6.0
```

This will update the version in the following files:

 * `lib/CMakeLists.txt`
 * `lib/lib.gni`, automatically updated with
   `tools/scripts/build_cleaner.py --update`.
 * `debian/changelog` to create the Debian package release with the new version.
   Debian changelog shouldn't repeat the library changelog, instead it should
   include changes to the packaging scripts.
 * `.github/workflows/conformance.yml`

If there were incompatible API/ABI changes, make sure to also adapt the
corresponding section in
[CMakeLists.txt](https://github.com/libjxl/libjxl/blob/main/lib/CMakeLists.txt#L12).

## Cherry-pick fixes to a release

After a Pull Request that should be included in a release branch has been merged
to `main` it can be cherry-picked to the release branch. Before cherry-picking a
change to a release branch it is important to check that it doesn't introduce
more problems, in particular it should run for some time in `main` to make sure
post-submit tests and the fuzzers run on it. Waiting for a day is a good idea.

Most of the testing is done on the `main` branch, so be careful with what
commits are cherry-picked to a branch. Refactoring code is often not a good
candidate to cherry-pick.

To cherry-pick a single commit to a release branch (in this example to `v0.5.x`)
you can run:

```bash
git fetch origin
git checkout origin/v0.5.x -b merge_to_release
git cherry-pick -x SHA_OF_MAIN_COMMIT
# -x will annotate the cherry-pick with the original SHA_OF_MAIN_COMMIT value.
# If not already mentioned in the original commit, add the original PR number to
# the commit, for example add "(cherry picked from PR #NNNN)".
git commit --amend
```

The `SHA_OF_MAIN_COMMIT` is the hash of the commit as it landed in main. Use
`git log origin/main` to list the recent main commits and their hashes.

Making sure that the commit message on the cherry-picked commit contains a
reference to the original pull request (like `#NNNN`) is important. It creates
an automatic comment in the original pull request notifying that it was
mentioned in another commit, helping keep track of the merged pull requests. If
the original commit was merged with the "Squash and merge" policy it will
automatically contain the pull request number on the first line, if this is not
the case you can amend the commit message of the cherry-pick to include a
reference.

Multiple commits can be cherry-picked and tested at once to save time. Continue
running `git cherry-pick` and `git commit --amend` multiple times for all the
commits you need to cherry-pick, ideally in the same order they were merged on
the `main` branch. At the end you will have a local branch with multiple commits
on top of the release branch.

To update the version number, for example from v0.8.0 to v0.8.1 run this helper
command (in a Debian-based system):

```bash
./ci.sh bump_version 0.8.1
```

as described above and commit the changes.

Finally, upload your changes to *your fork* like normal, except that when
creating a pull request select the desired release branch as a target:

```bash
git push myfork merge_to_release
```

If you used the [guide](developing_in_github.md) `myfork` would be `origin` in
that example. Click on the URL displayed, which will be something like

  `https://github.com/mygithubusername/libjxl/pull/new/merge_to_release`

In the "Open a pull request" page, change the drop-down base branch from
"base: main" (the default) to the release branch you are targeting.

The pull request approval and pre-submit rules apply as with normal pull
requests to the `main` branch.

**Important:** When merging multiple cherry-picks use "Rebase and merge" policy,
not the squash one since otherwise you would discard the individual commit
message references from the git history in the release branch.

## Publishing a release

Once a release tag is created it must not be modified, so you need to prepare
the changes before creating the release. Make sure you checked the following:

 * The semantic version number in the release branch (see `lib/CMakeLists.txt`)
   matches the number you intend to release, all three MAJOR, MINOR and PATCH
   should match. Otherwise send a pull request to the release branch to
   update them.

 * The GitHub Actions checks pass on the release branch. Look for the green
   tick next to the last commit on the release branch. This should be visible
   on the branch page, for example: https://github.com/libjxl/libjxl/tree/v0.5.x

 * There no open fuzzer-found bugs for the release branch. The most effective
   way is to [run the fuzzer](fuzzing.md) on the release branch for a while. You
   can seed the fuzzer with corpus generated by oss-fuzz by [downloading
   it](https://google.github.io/oss-fuzz/advanced-topics/corpora/#downloading-the-corpus),
   for example `djxl_fuzzer` with libFuzzer will use:
   gs://libjxl-corpus.clusterfuzz-external.appspot.com/libFuzzer/libjxl_djxl_fuzzer

 * Manually check that images encode/decode ok.

 * Manually check that downstream projects compile with our code. Sometimes
   bugs on build scripts are only detected when other projects try to use our
   library. For example, test compiling
   [imagemagick](https://github.com/ImageMagick/ImageMagick) and Chrome.

A [GitHub
"release"](https://docs.github.com/en/github/administering-a-repository/releasing-projects-on-github/about-releases)
consists of two different concepts:

 * a git "tag": this is a name (`v` plus the semantic version number) with a
   commit hash associated, defined in the git repository. Most external projects
   will use git tags or HTTP URLs to these tags to fetch the code.

 * a GitHub "release": this is a GitHub-only concept and is not represented in
   git other than by having a git tag associated with the release. A GitHub
   release has a given source code commit SHA associated (through the tag) but
   it *also* contains release notes and optional binary files attached to the
   release.

Releases from the older GitLab repository only have a git tag in GitHub, while
newer releases have both a git tag and a release entry in GitHub.

To publish a release open the [New Release
page](https://github.com/libjxl/libjxl/releases/new) and follow these
instructions:

 * Set the "Tag version" as "v" plus the semantic version number.

 * Select the "Target" as your release branch. For example for a "v0.7.1"
   release tag you should use the "v0.7.x" branch.

 * Use the version number as the release title.

 * Copy-paste the relevant section of the [CHANGELOG.md](../CHANGELOG.md) to the
   release notes into the release notes. Add any other information pertaining
   the release itself that are not included in the CHANGELOG.md, although prefer
   to include those in the CHANGELOG.md file. You can switch to the Preview tab
   to see the results.

 * Finally click "Publish release" and go celebrate with the team. 🎉

 * Make sure to manually push the commit of the release also to https://gitlab.com/wg1/jpeg-xl.

### How to build downstream projects

```bash
docker run -it debian:bullseye /bin/bash

apt update
apt install -y clang cmake git libbrotli-dev nasm pkg-config ninja-build
export CC=clang
export CXX=clang++

git clone --recurse-submodules --depth 1 -b v0.7.x \
  https://github.com/libjxl/libjxl.git
git clone --recurse-submodules --depth 1 \
  https://github.com/ImageMagick/ImageMagick.git
git clone --recurse-submodules --depth 1 \
  https://github.com/FFmpeg/FFmpeg.git

cd ~/libjxl
git checkout v0.7.x
cmake -B build -G Ninja .
cmake --build build
cmake --install build

cd ~/ImageMagick
./configure --with-jxl=yes
# check for "JPEG XL --with-jxl=yes yes"
make -j 80

cd ~/FFmpeg
./configure --enable-libjxl
# check for libjxl decoder/encoder support
make -j 80
```
