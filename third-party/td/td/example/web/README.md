# TDLib Web example

This is an example of building `TDLib` for browsers using [Emscripten](https://github.com/kripken/emscripten).
These scripts build `TDLib` and create an [NPM](https://www.npmjs.com/) package [tdweb](https://www.npmjs.com/package/tdweb).
You need a Unix shell with `sed`, `tar` and `wget` utilities to run the provided scripts.

## Building tdweb NPM package

* Install the 3.1.1 [emsdk](https://kripken.github.io/emscripten-site/docs/getting_started/downloads.html), which is known to work. Do not use the system-provided `emscripten` package, because it contains a too old emsdk version.
* Install all `TDLib` build dependencies described in [Building](https://github.com/tdlib/td#building) and `sed`, `tar` and `wget` utilities.
* Run `source ./emsdk_env.sh` from `emsdk` directory to set up the correct build environment.
* On `macOS`, install the `coreutils` [Homebrew](https://brew.sh) package and replace `realpath` in scripts with `grealpath`:
```
brew install coreutils
sed -i.bak 's/[(]realpath/(grealpath/g' build-tdlib.sh
```
* Run build scripts in the following order:
```
cd <path to TDLib sources>/example/web
./build-openssl.sh
./build-tdlib.sh
./copy-tdlib.sh
./build-tdweb.sh
```
* The built package is now located in the `tdweb` directory.

## Using tdweb NPM package

See [tdweb](https://www.npmjs.com/package/tdweb) or [README.md](https://github.com/tdlib/td/tree/master/example/web/tdweb/README.md) for package documentation.
