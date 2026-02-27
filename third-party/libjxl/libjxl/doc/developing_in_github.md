# Developing in GitHub

This document describes the development steps related to handling the git
repository.

If you are new to GitHub, there's a nice [quickstart
guide](https://docs.github.com/en/github/getting-started-with-github/quickstart)
on GitHub explaining the basics.

## Initial setup

You need to perform this set up at least once if you haven't use GitHub before.
Read through the quickstart guide [Set up
Git](https://docs.github.com/en/github/getting-started-with-github/set-up-git)
page to get your git up and running. You will need to Fork a repository next.
After that "Life of a Pull Request" describes the common everyday workflows.

### Configure your SSH access

The easiest way to configure access to your Github repository is to use SSH
keys. For that you need an SSH private and public key, ideally a strong one. You
can use different keys for different sites if you want. In this example, we will
create one for using in GitHub only.

Create the `~/.ssh/id_rsa_github` file executing the following. (Here and
elsewhere, {{X}} are placeholders for your email/username)

```bash
ssh-keygen -t rsa -b 4096 -C "{{EMAIL}}" -f ~/.ssh/id_rsa_github
```

Go to your [SSH and GPG keys](https://github.com/settings/keys) settings and
paste the contents of your *public key* (the one ending in `.pub`), that would
be the output of this command:

```bash
cat ~/.ssh/id_rsa_github.pub
```

To use a specific key when SSHing to the github.com domain, you can add this
snippet of config to your .ssh/config file executing the following.

```bash
cat >> ~/.ssh/config <<EOF

Host github.com
  Hostname github.com
  IdentityFile ~/.ssh/id_rsa_github
  IdentitiesOnly yes
EOF
```

The `IdentitiesOnly yes` part forces to only use the provided IdentityFile when
talking to GitHub.

### Fork your private copy

The JPEG XL code is located in [this repo](https://github.com/libjxl/libjxl).

The normal developer workflow in GitHub involves creating your own fork of a
repository and uploading your own changes there. From your own copy you can
request merges *to* the upstream repository directly, there's no need to create
a branch in the upstream repository.

[Fork the
repository](https://docs.github.com/en/github/getting-started-with-github/fork-a-repo)
in GitHub to create your own copy of the repository in GitHub. You can then
propose to include changes in the main repository via a Pull Request.

Once you are done you should have your repository at

 https://<!-- not a link -->github.com<!-- not a link -->/*{{USERNAME}}*/libjxl

where {{USERNAME}} denotes your GitHub username.

### Checkout the JPEG XL code from GitHub

To get the source code on your computer you need to "clone" it. There are two
repositories at play here, the upstream repository (`libjxl/lbjxl`) and your
fork (`{{USERNAME}}/libjxl`). You will be normally fetching new changes from
the upstream repository and push changes to your fork. Getting your changes from
your fork to the upstream repository is done through the Web interface, via Pull
Requests.

The [Fork a
repo](https://docs.github.com/en/github/getting-started-with-github/fork-a-repo)
goes in great detail, but uses the git remote names `upstream` for the shared
upstream repository and `origin` for your work. This guide proposes an
alternative naming scheme, used in the examples below.

In this guide `origin` is the upstream shared repository and `myfork` is your
fork. You can use any other name for your fork if you want. Use the following
commands to set things up, replacing `{{USERNAME}}` with your GitHub username:

```bash
git clone git https://github.com/libjxl/libjxl --recursive
cd libjxl
git remote set-url --push origin git@github.com:{{USERNAME}}/libjxl.git
git remote add myfork git@github.com:{{USERNAME}}/libjxl.git
git remote -vv
```

These commands did three things:

 * Created the repository with `origin` as the upstream remote,
 * Changed the "push" URL to point to your fork, and
 * Create a new remote pointing to your fork.

The last step is optional. Since the "fetch" URL of `origin` points to the
shared repository and the "push" URL points to your fork, fetching from `origin`
always gets the latest changes from the upstream repository regardless of the
contents of your fork.

Having a second origin called `myfork` is only useful if you need to download
pending changes from your fork from a different computer. For example, if you
work on multiple computers, each one with this setup, you can push to your
fork from one, and then fetch from `myfork` from another computer to get those.

# Life of a Pull Request

The general [GitHub flow
guide](https://docs.github.com/en/github/getting-started-with-github/github-flow)
applies to sending Pull Requests to this project.

All the commands here assume you are in a git checkout as setup here.

### Sync to the latest version

```bash
git fetch origin
```

The last upstream version is now on `origin/main` and none of your local
branches have been modified by this command.

### Start a new branch

To start a new change you need a local branch. Each branch will represent a list
of individual commits which can then be requested to be merged as a single merge
request. So in general one branch is one code review, but each branch can have
multiple individual commits in it.

```bash
git checkout origin/main -b mybranch
```

This will create a new branch `mybranch` tracking `origin/main`. A branch can
track any remove or local branch, which is used by some tools. Running `git
branch -vv` will show all the branches you have have, what are they tracking and
how many commits are ahead or behind. If you create a branch without tracking
any other, you can add or change the tracking branch of the current branch
running `git branch --set-upstream-to=...`.

### Add changes to your branch

Follow any of the many online tutorials, for example
[The basics](https://git-scm.com/book/en/v2/Git-Basics-Getting-a-Git-Repository)
chapter from the https://git-scm.com/doc website is a good starting guide.
Create, change or delete files and do a git commit with a message.

The commit message is required. A commit message should follow the 50/72 rule:

*   First line is 50 characters or less.
*   Then a blank line.
*   Remaining text should be wrapped at 72 characters.

The first line should identify your commit, since that's what most tools will
show to the user. First lines like "Some fixes" are not useful. Explain what the
commit contains and why.

We follow the [Google C++ Coding
Style](https://google.github.io/styleguide/cppguide.html). A
[clang-format](https://clang.llvm.org/docs/ClangFormat.html) configuration
file is available to automatically format your code, you can invoke it with
the `./ci.sh lint` helper tool.

Read the [CONTRIBUTING.md](../CONTRIBUTING.md) file for more information about
contributing to libjxl.

### Upload your changes for review

The first step is a local review of your changes to see what will you be sending
for review. `gitg` is a nice Gtk UI for reviewing your local changes, or `tig`
for similar ncurses console-based interface. Otherwise, from the terminal you
can run:

```bash
git branch -vv
```

To show the current status of your local branches. In particular, since your
branch is tracking origin/main (as seen in the output) git will tell you that
you are one commit ahead of the tracking branch.

```
* mybranch       e74ae1a [origin/main: ahead 1] Improved decoding speed by 40%
```

It is a good idea before uploading to sync again with upstream (`git fetch
origin`) and then run `git branch -vv` to check whether there are new changes
upstream. If that is the case, you will see a "behind" flag in the output:

```
* mybranch       e74ae1a [origin/main: ahead 1, behind 2] Improved decoding speed by 40%
```

To sync your changes on top of the latest changes in upstream you need to
rebase:

```bash
git rebase
```

This will by default rebase your current branch changes on top of the tracking
branch. In this case, this will try to apply the current commit on top of the
latest origin/main (which has 2 more commits than the ones we have in our
branch) and your branch will now include that. There could be conflicts that you
have to deal with. A shortcut to do both fetch and rebase is to run `git pull
-r`, where the `-r` stands for "rebase" and will rebase the local commits on top
of the remote ones.

Before uploading a patch, make sure your patch conforms to the
[contributing guidelines](../CONTRIBUTING.md) and it
[builds and passes tests](building_and_testing.md).

Once you are ready to send your branch for review, upload it to *your* fork:

```bash
git push origin mybranch
```

This will push your local branch "mybranch" to a remote in your fork called
"mybranch". The name can be anything, but keep in mind that it is public. A link
to the URL to create a merge request will be displayed.

```
Enumerating objects: 627, done.
Counting objects: 100% (627/627), done.
Delta compression using up to 56 threads
Compressing objects: 100% (388/388), done.
Writing objects: 100% (389/389), 10.71 MiB | 8.34 MiB/s, done.
Total 389 (delta 236), reused 0 (delta 0)
emote:
remote: Create a pull request for 'mybranch' on GitHub by visiting:
remote:      https://github.com/{{USERNAME}}/libjxl/pull/new/mybranch
remote:
To github.com:{{USERNAME}}/libjxl.git
 * [new branch]      mybranch -> mybranch
```

### Updating submodules

The repository uses submodules for external library dependencies in
third_party. Each submodule points to a particular external commit of the
external repository by the hash code of that external commit. Just like
regular source code files, this hash code is part of the current branch and
jpeg xl commit you have checked out.

When changing branches or when doing `git rebase`, git will unfortunately
*not* automatically set those hashes to the ones of the branch or jpeg xl
commit you changed to nor set the source files of the third_party submodules
to the new state. That is, even though git will have updated the jpeg xl
source code files on your disk to the new ones, it will leave the submodule
hashes and the files in third_party in your workspace to the ones they were
before you changed branches. This will show up in a git diff because this
is seen as a change compared to the branch you switched to. The git diff shows
the difference in hash codes (as if you are changing to the old ones), it does
not show changes in files inside the third_party directory.

This mismatch can cause at least two problems:

*) the jpeg xl codebase may not compile due to third_party library version
mismatch if e.g. API changed or a submodule was added/removed.

*) when using `commit -a` your commit, which may be a technical change
unrelated to submodule changes, will unintentionally contain a change to the
submodules hash code, which is undesired unless you actually want to change
the version of third_party libraries.

To resolve this, the submodules must be updated manually with
the following command after those actions (at least when the submodules
changed):

```
git submodule update --init --recursive
```

Here, the init flag ensures new modules get added when encessary and the
recursive flag is required for the submodules depending on other submodules.

If you checkout a different branch, you can spot that submodules changed
when it shows a message similar to this:

```
M       third_party/brotli
M       third_party/lcms
```

If you do a rebase you may end up in a harder to solve situation, where
`git submodule update --init --recursive` itself fails with errors such as:

```
Unable to checkout '35ef5c554d888bef217d449346067de05e269b30' in submodule path 'third_party/brotli'
```

In that case, you can use the force flag:

```
git submodule update --init --recursive --force
```

### Iterating changes in your merge request

To address reviewer changes you need to amend the local changes in your branch
first. Make the changes you need in your commit locally by running `git commit
--amend file1 file2 file3 ...` or `git commit --amend -a` to amend all the
changes from all the staged files.

Once you have the new version of the "mybranch" branch to re-upload, you need to
force push it to the same branch in your fork. Since you are pushing a different
version of the same commit (as opposed to another commit on top of the existing
ones), you need to force the operation to replace the old version.

```bash
git push origin mybranch --force
```

The merge request should now be updated with the new changes.

### Merging your changes

We use "rebase" as a merge policy, which means that there a no "merge" commits
(commits with more than one parent) but instead only a linear history of
changes.

It is possible that other changes where added to the main branch since the last
time you rebased your changes. These changes could create a conflict with your
Pull Request, if so you need to `git fetch`, `git rebase` and push again your
changes which need to go through the continuous integration workflow again to
verify that all the tests pass again after including the latest changes.

### Trying locally a pending Pull Request

If you want to review in your computer a pending pull request proposed by
another user you can fetch the merge request commit with the following command,
replacing `NNNN` with the pull request number:

```bash
git fetch origin refs/pull/NNNN/head
git checkout FETCH_HEAD
```

The first command will add to your local git repository the remote commit for
the pending pull request and store a temporary reference called `FETCH_HEAD`.
The second command then checks out that reference. From this point you can
review the files in your computer, create a local branch for this FETCH_HEAD or
build on top of it.
