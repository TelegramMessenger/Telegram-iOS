# Developing for Windows with MSYS2

[MSYS2](https://www.msys2.org/) ("minimal system 2") is a software distribution and a development platform based on MinGW and Cygwin.  It provides a  Unix-like environment to build code on Windows.  These instructions were written with a 64-bit instance of Windows 10 running on a VM.  They may also work on native instances of Windows and other versions of Windows.

## Build Environments

MSYS2 provides multiple development [environments](https://www.msys2.org/docs/environments/).  By convention, they are referred to in uppercase.  They target slightly different platforms, runtime libraries, and compiler toolchains.  For example, to build for 32-bit Windows, use the MINGW32 environment.  For interoperability with Visual Studio projects, use the UCRT64 environment.

Since all of the build environments are built on top of the MSYS environment, **all updates and package installation must be done from within the MSYS environment**.  After making any package changes, `exit` all MSYS2 terminals and restart the desired build-environment.  This reminder is repeated multiple times throughout this guide.

* **MINGW32:**  To compile for 32-bit Windows (on 64-bit Windows), use packages from the `mingw32` group.  Package names are prefixed with `mingw-w64-i686`.  The naming scheme may be different on the 32-bit version of MSYS2.

* **MINGW64:**  This is the primary environment to building for 64-bit Windows.  It uses the older MSVCRT runtime, which is widely available across Windows systems.  Package names are prefixed with `mingw-w64-x86_64`.

* **UCRT64:**  The Universal C Runtime (UCRT) is used by recent versions of Microsoft Visual Studio.  It ships by default with Windows 10.  For older versions of Windows, it must be provided with the application or installed by the user.  Package names are prefixed with `mingw-w64-ucrt-x86_64`.

* **CLANG64:** Unfortunately, the `gimp` packages are not available for the CLANG64 environment.  However, `libjxl` will otherwise build in this environment if the appropriate packages are installed.  Packages are prefixed with `mingw-w64-clang-x86_64`.

## Install and Upgrade MSYS2

Download MSYS2 from the homepage.  Install at a location without any spaces on a drive with ample free space.  After installing the packages used in this guide, MSYS2 used about 15GB of space.

Toward the end of installation, select the option to run MSYS2 now.  A command-line window will open.  Run the following command, and answer the prompts to update the repository and close the terminal.

```bash
pacman -Syu
```

Now restart the MSYS environment and run the following command to complete updates:

```bash
pacman -Su
```

## Package Management

Packages are organized in groups, which share the build environment name, but in lower case.  Then they have name prefixes that indicate which group they belong to.  Consider this package search: `pacman -Ss cmake`

```
mingw32/mingw-w64-i686-cmake
mingw64/mingw-w64-x86_64-cmake
ucrt64/mingw-w64-ucrt-x86_64-cmake
clang64/mingw-w64-clang-x86_64-cmake
msys/cmake
```

We can see the organization `group/prefix-name`.  When installing packages, the group name is optional.

```bash
pacman -S mingw-w64-x86_64-cmake
```
 
For tools that need to be aware of the compiler to function, install the package that corresponds with the specific build-environment you plan to use.  For `cmake`, install the `mingw64` version.  The generic `msys/cmake` will not function correctly because it will not find the compiler.  For other tools, the generic `msys` version is adequate, like `msys/git`.

To remove packages, use:

```bash
pacman -Rsc [package-name]
```

## Worst-Case Scenario...

If packages management is done within a build environment other than MSYS, the environment structure will be disrupted and compilation will likely fail.  If this happens, it may be necessary to reinstall MSYS2.

1. Rename the `msys64` folder to `msys64.bak`.

2. Use the installer to reinstall MSYS2 to `msys64`.

3. Copy packages from `msys64.bak/var/cache/pacman/pkg/` to the new installation to save download time and bandwidth.

4. Use `pacman` from within the MSYS environment to install and update packages.

5. After successfully building a project, it is safe to delete `msys64.bak`

## The MING64 Environment

Next set up the MING64 environment.  The following commands should be run within the MSYS environment.  `pacman -S` is used to install packages.  The `--needed` argument prevents packages from being reinstalled.

```bash
pacman -S --needed base-devel mingw-w64-x86_64-toolchain
pacman -S git mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja \
    mingw-w64-x86_64-gtest mingw-w64-x86_64-giflib \
    mingw-w64-x86_64-libpng mingw-w64-x86_64-libjpeg-turbo 
```

## Build `libjxl`

Download the source from the libjxl [releases](https://github.com/libjxl/libjxl/releases) page.  Alternatively, you may obtain the latest development version with `git`.  Run `./deps.sh` to ensure additional third-party dependencies are downloaded.

Start the MINGW64 environment, create a build directory within the source directory, and configure with `cmake`.

```bash
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo \
   -DBUILD_TESTING=OFF -DBUILD_SHARED_LIBS=OFF \
   -DJPEGXL_ENABLE_BENCHMARK=OFF -DJPEGXL_ENABLE_PLUGINS=ON \
   -DJPEGXL_ENABLE_MANPAGES=OFF -DJPEGXL_FORCE_SYSTEM_BROTLI=ON \
   -DJPEGXL_FORCE_SYSTEM_GTEST=ON ..
```

Check the output to see if any dependencies were missed and need to be installed.  Adding `-G Ninja` may be helpful, but on my computer, Ninja was selected by default.  Remember that package changes must be done from the MSYS environment.  Then exit all MSYS2 terminals and restart the build environment.

If all went well, you may now run `cmake` to build `libjxl`:

```bash
cmake --build .
```

Do not be alarmed by the compiler warnings.  They are a caused by differences between gcc/g++ and clang.  The build should complete successfully.  Then `cjxl`, `djxl`, `jxlinfo`, and others can be run from within the build environment.  Moving them into the native Windows environment requires resolving `dll` issues that are beyond the scope of this document.

## The `clang` Compiler

To use the `clang` compiler, install the packages that correspond with the environment you wish to use.  Remember to make package changes from within the MSYS environment.

```
mingw-w64-i686-clang
mingw-w64-i686-clang-tools-extra
mingw-w64-i686-clang-compiler-rt

mingw-w64-x86_64-clang
mingw-w64-x86_64-clang-tools-extra
mingw-w64-x86_64-clang-compiler-rt

mingw-w64-ucrt64-x86_64-clang
mingw-w64-ucrt64-x86_64-clang-tools-extra
mingw-w64-ucrt64-x86_64-clang-compiler-rt
```

After the `clang` compiler is installed, 'libjxl' can be built with the `./ci.sh` script.

```bash
./ci.sh opt -DBUILD_TESTING=OFF -DBUILD_SHARED_LIBS=OFF \
    -DJPEGXL_ENABLE_BENCHMARK=OFF -DJPEGXL_ENABLE_MANPAGES=OFF \
    -DJPEGXL_FORCE_SYSTEM_BROTLI=ON -DJPEGXL_FORCE_SYSTEM_GTEST=ON
```

On my computer, `doxygen` packages needed to be installed to proceed with building.  Use `pacman -Ss doxygen` to find the packages to install.

## The GIMP Plugin

To build the GIMP plugin, install the relevant `gimp` package.  This will also install dependencies.  Again, perform package management tasks from only the MSYS environment.  Then restart the build environment.

```bash
pacman -S mingw-w64-i686-gimp
pacman -S mingw-w64-x86_64-gimp
pacman -S mingw-w64-ucrt-x86_64-gimp
```

If `clang` is installed, you can use the `./ci.sh` script to build.  Otherwise, navigate to the build directory to reconfigure and build with `cmake`.

```bash
cd build
rm -r CM*
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo \
   -DBUILD_TESTING=OFF -DBUILD_SHARED_LIBS=OFF \
   -DJPEGXL_ENABLE_BENCHMARK=OFF -DJPEGXL_ENABLE_MANPAGES=OFF \
   -DJPEGXL_ENABLE_PLUGINS=ON -DJPEGXL_FORCE_SYSTEM_BROTLI=ON \
   -DJPEGXL_FORCE_SYSTEM_GTEST=ON ..
```

The plugin is built statically, so there should be no need to install `dll` files.  To try out the plugin:

1. [Download](https://www.gimp.org/downloads/) and install the stable version of GIMP (currently 2.10.24).

2. Create a new folder: `C:\Program Files\GIMP 2\lib\gimp\2.0\plug-ins\file-jxl`

3. Copy `build/plugins/gimp/file-jxl.exe` to the new folder.
