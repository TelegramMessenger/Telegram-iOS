# Compilation

For more details and other workflows see the "Advanced guide" below.

## Checking out the code

```bash
git clone https://github.com/libjxl/libjxl.git --recursive --shallow-submodules
```

This repository uses git submodules to handle some third party dependencies
under `third_party`, that's why it is important to pass `--recursive`. If you
didn't check out with `--recursive`, or any submodule has changed, run:

```bash
git submodule update --init --recursive --depth 1 --recommend-shallow
```

The `--shallow-submodules` and `--depth 1 --recommend-shallow` options create
shallow clones which only downloads the commits requested, and is all that is
needed to build `libjxl`. Should full clones be necessary, you could always run:

```bash
git submodule foreach git fetch --unshallow
git submodule update --init --recursive
```

which pulls the rest of the commits in the submodules.

Important: If you downloaded a zip file or tarball from the web interface you
won't get the needed submodules and the code will not compile. You can download
these external dependencies from source running `./deps.sh`. The git workflow
described above is recommended instead.

## Installing dependencies

Required dependencies for compiling the code, in a Debian/Ubuntu based
distribution run:

```bash
sudo apt install cmake pkg-config libbrotli-dev
```

Optional dependencies for supporting other formats in the `cjxl`/`djxl` tools,
in a Debian/Ubuntu based distribution run:

```bash
sudo apt install libgif-dev libjpeg-dev libopenexr-dev libpng-dev libwebp-dev
```

We recommend using a recent Clang compiler (version 7 or newer), for that
install clang and set `CC` and `CXX` variables.

```bash
sudo apt install clang
export CC=clang CXX=clang++
```

## Building

```bash
cd libjxl
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF ..
cmake --build . -- -j$(nproc)
```

The encoder/decoder tools will be available in the `build/tools` directory.

## <a name="installing"></a> Installing

```bash
sudo cmake --install .
```


## Building JPEG XL for developers

For experienced developers, we provide build instructions for several other environments:

*   [Building on Debian](doc/developing_in_debian.md)
*   Building on Windows with [vcpkg](doc/developing_in_windows_vcpkg.md) (Visual Studio 2019)
*   Building on Windows with [MSYS2](doc/developing_in_windows_msys.md)
*   [Cross Compiling for Windows with Crossroad](doc/developing_with_crossroad.md)
