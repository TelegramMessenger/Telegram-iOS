## Disclaimer

OSX builds have "best effort" support, i.e. build might not work at all, some
tests may fail and some sub-projects are excluded from build.

This manual outlines OSX specific setup. For general building and testing
instructions see "[BUILDING](BUILDING.md)" and
"[Building and Testing changes](doc/building_and_testing.md)".

[Homebrew](https://brew.sh/) is a popular package manager. JPEG XL library and
binaries could be installed using it:

```bash
brew install jpeg-xl
```

## Dependencies

Make sure that `brew doctor` does not report serious problems and up-to-date
version of XCode is installed.

Installing (actually, building) `clang` might take a couple hours.

```bash
brew install llvm
```

```bash
brew install coreutils cmake giflib jpeg-turbo libpng ninja zlib
```

Before building the project check that `which clang` is
`/usr/local/opt/llvm/bin/clang`, not the one provided by XCode. If not, update
`PATH` environment variable.

Also, setting `CMAKE_PREFIX_PATH` might be necessary for correct include paths
resolving, e.g.:

```bash
export CMAKE_PREFIX_PATH=`brew --prefix giflib`:`brew --prefix jpeg-turbo`:`brew --prefix libpng`:`brew --prefix zlib`
```