# Cross Compiling for Windows with Crossroad

[Crossroad](https://pypi.org/project/crossroad/) is a tool to set up cross-compilation environments on GNU/Linux distributions.  These instructions assume a Debian/Ubuntu system.  However, they can likely be adapted to other Linux environments.  Since Ubuntu can be run on Windows through WSL, these instruction may be useful for developing directly on Windows.

## Install Crossroad

Crossroad requires tools included with `python3-docutils` and `mingw-w64`.  They may be installed using:

```bash
sudo aptitude install python3-docutils mingw-w64
```

The `zstandard` python package is also required, but is not available in the repositories.  It may be installed using `pip`.

```bash
pip3 install zstandard
```

After the dependencies are installed, crossroad itself maybe installed with `pip`.

```bash
pip3 install crossroad
```

If there are errors while running crossroad, it may need to be downloaded and installed directly using `setup.py`.  Instructions are on the crossroad homepage.

## Update Debian Alternatives

Since `libjxl` uses C++ features that require posix threads, the symlinks used by the Debian alternative system need to be updated:

```bash
sudo update-alternatives --config x86_64-w64-mingw32-g++
```

Select the option that indicates `posix` usage.  Repeat for `gcc` and `i686`:

```bash
sudo update-alternatives --config x86_64-w64-mingw32-gcc
sudo update-alternatives --config i686-w64-mingw32-gcc
sudo update-alternatives --config i686-w64-mingw32-g++
```

## Create a New Crossroad Project

Crossroad supports the following platforms:

```
native               Native platform (x86_64 GNU/Linux)
android-x86          Generic Android/Bionic on x86
android-mips64       Generic Android/Bionic on MIPS64
android-x86-64       Generic Android/Bionic on x86-64
w64                  Windows 64-bit
w32                  Windows 32-bit
android-arm64        Generic Android/Bionic on ARM64
android-mips         Generic Android/Bionic on MIPS
android-arm          Generic Android/Bionic on ARM
```

To begin cross compiling for Windows, a new project needs to be created:

```bash
crossroad w64 [project-name]
```

## Install Dependencies

Since the `gimp` development package is required to build the GIMP plugin and also includes most of the packages required by `libjxl`, install it first.

```bash
crossroad install gimp
```

`gtest` and `brotli` are also required.

```bash
crossroad install gtest brotli
```

If any packages are later found to be missing, you may search for them using:

```bash
crossroad search [...]
```

## Build `libjxl`

Download the source from the libjxl [releases](https://github.com/libjxl/libjxl/releases) page.  Alternatively, you may obtain the latest development version with `git`.  Run `./deps.sh` to ensure additional third-party dependencies are downloaded.  Unfortunately, the script `./ci.sh` does not work with Crossroad, so `cmake` will need to be called directly.

Create a build directory within the source directory.  If you haven't already, start your crossroad project and run `cmake`:

```bash
mkdir build
cd build
crossroad w64 libjxl
crossroad cmake -DCMAKE_BUILD_TYPE=Release \
   -DBUILD_TESTING=OFF -DBUILD_SHARED_LIBS=OFF \
   -DJPEGXL_ENABLE_BENCHMARK=OFF -DJPEGXL_ENABLE_MANPAGES=OFF \
   -DJPEGXL_ENABLE_PLUGINS=ON -DJPEGXL_FORCE_SYSTEM_BROTLI=ON \
   -DJPEGXL_FORCE_SYSTEM_GTEST=ON ..
```

Check the output to see if any dependencies were missed and need to be installed.  If all went well, you may now run `cmake` to build `libjxl`:

```bash
cmake --build .
```

## Try out the GIMP Plugin

The plugin is built statically, so there should be no need to install `dll` files.  To try out the plugin:

1. [Download](https://www.gimp.org/downloads/) and install the stable version of GIMP (currently 2.10.24).

2. Create a new folder: `C:\Program Files\GIMP 2\lib\gimp\2.0\plug-ins\file-jxl`

3. Copy `build/plugins/gimp/file-jxl.exe` to the new folder. 
