Building libjpeg-turbo
======================


Build Requirements
------------------


### All Systems

- [CMake](http://www.cmake.org) v2.8.12 or later

- [NASM](http://www.nasm.us) or [Yasm](http://yasm.tortall.net)
  (if building x86 or x86-64 SIMD extensions)
  * If using NASM, 2.13 or later is required.
  * If using Yasm, 1.2.0 or later is required.
  * If building on macOS, NASM or Yasm can be obtained from
    [MacPorts](http://www.macports.org/) or [Homebrew](http://brew.sh/).
     - NOTE: Currently, if it is desirable to hide the SIMD function symbols in
       Mac executables or shared libraries that statically link with
       libjpeg-turbo, then NASM 2.14 or later or Yasm must be used when
       building libjpeg-turbo.
  * If NASM or Yasm is not in your `PATH`, then you can specify the full path
    to the assembler by using either the `CMAKE_ASM_NASM_COMPILER` CMake
    variable or the `ASM_NASM` environment variable.  On Windows, use forward
    slashes rather than backslashes in the path (for example,
    **c:/nasm/nasm.exe**).
  * NASM and Yasm are located in the CRB (Code Ready Builder) or PowerTools
    repository on Red Hat Enterprise Linux 8+ and derivatives, which is not
    enabled by default.

### Un*x Platforms (including Linux, Mac, FreeBSD, Solaris, and Cygwin)

- GCC v4.1 (or later) or Clang recommended for best performance

- If building the TurboJPEG Java wrapper, JDK or OpenJDK 1.5 or later is
  required.  Most modern Linux distributions, as well as Solaris 10 and later,
  include JDK or OpenJDK.  For other systems, you can obtain the Oracle Java
  Development Kit from
  <http://www.oracle.com/technetwork/java/javase/downloads>.

  * If using JDK 11 or later, CMake 3.10.x or later must also be used.

### Windows

- Microsoft Visual C++ 2005 or later

  If you don't already have Visual C++, then the easiest way to get it is by
  installing
  [Visual Studio Community Edition](https://visualstudio.microsoft.com).

  * You can also download and install the standalone Windows SDK (for Windows 7
    or later), which includes command-line versions of the 32-bit and 64-bit
    Visual C++ compilers.
  * If you intend to build libjpeg-turbo from the command line, then add the
    appropriate compiler and SDK directories to the `INCLUDE`, `LIB`, and
    `PATH` environment variables.  This is generally accomplished by
    executing `vcvars32.bat` or `vcvars64.bat`, which are located in the same
    directory as the compiler.
  * If built with Visual C++ 2015 or later, the libjpeg-turbo static libraries
    cannot be used with earlier versions of Visual C++, and vice versa.
  * The libjpeg API DLL (**jpeg{version}.dll**) will depend on the C run-time
    DLLs corresponding to the version of Visual C++ that was used to build it.
    
- Vcpkg
  
  You need to download and install libpng using the [vcpkg](https://github.com/Microsoft/vcpkg) dependency manager:

      git clone https://github.com/Microsoft/vcpkg.git
      cd vcpkg
      ./bootstrap-vcpkg.sh
      ./vcpkg integrate install
      vcpkg install libpng:x64-windows
      vcpkg install libpng:x64-windows-static
      
  Actually, you can just download and install MozJPEG using vcpkg dependency manager:
      
      vcpkg install mozjpeg
  
  The mozjpeg port in vcpkg is kept up to date by Microsoft team members and community contributors. If the version is out of date, please [create an issue or pull request](https://github.com/Microsoft/vcpkg) on the vcpkg repository.


   ... OR ...


- MinGW

  [MSYS2](http://msys2.github.io/) or [tdm-gcc](http://tdm-gcc.tdragon.net/)
  recommended if building on a Windows machine.  Both distributions install a
  Start Menu link that can be used to launch a command prompt with the
  appropriate compiler paths automatically set.

- If building the TurboJPEG Java wrapper, JDK 1.5 or later is required.  This
  can be downloaded from
  <http://www.oracle.com/technetwork/java/javase/downloads>.

  * If using JDK 11 or later, CMake 3.10.x or later must also be used.


Sub-Project Builds
------------------

The libjpeg-turbo build system does not support being included as a sub-project
using the CMake `add_subdirectory()` function.  Use the CMake
`ExternalProject_Add()` function instead.


Out-of-Tree Builds
------------------

Binary objects, libraries, and executables are generated in the directory from
which CMake is executed (the "binary directory"), and this directory need not
necessarily be the same as the libjpeg-turbo source directory.  You can create
multiple independent binary directories, in which different versions of
libjpeg-turbo can be built from the same source tree using different compilers
or settings.  In the sections below, *{build_directory}* refers to the binary
directory, whereas *{source_directory}* refers to the libjpeg-turbo source
directory.  For in-tree builds, these directories are the same.


Ninja
-----

If using Ninja, then replace `make` or `nmake` with `ninja`, and replace the
CMake generator (specified with the `-G` option) with `Ninja`, in all of the
procedures and recipes below.


Build Procedure
---------------

NOTE: The build procedures below assume that CMake is invoked from the command
line, but all of these procedures can be adapted to the CMake GUI as
well.


### Un*x

The following procedure will build libjpeg-turbo on Unix and Unix-like systems.
(On Solaris, this generates a 32-bit build.  See "Build Recipes" below for
64-bit build instructions.)

    cd {build_directory}
    cmake -G"Unix Makefiles" [additional CMake flags] {source_directory}
    make

This will generate the following files under *{build_directory}*:

**libjpeg.a**<br>
Static link library for the libjpeg API

**libjpeg.so.{version}** (Linux, Unix)<br>
**libjpeg.{version}.dylib** (Mac)<br>
**cygjpeg-{version}.dll** (Cygwin)<br>
Shared library for the libjpeg API

By default, *{version}* is 62.2.0, 7.2.0, or 8.1.2, depending on whether
libjpeg v6b (default), v7, or v8 emulation is enabled.  If using Cygwin,
*{version}* is 62, 7, or 8.

**libjpeg.so** (Linux, Unix)<br>
**libjpeg.dylib** (Mac)<br>
Development symlink for the libjpeg API

**libjpeg.dll.a** (Cygwin)<br>
Import library for the libjpeg API

**libturbojpeg.a**<br>
Static link library for the TurboJPEG API

**libturbojpeg.so.0.2.0** (Linux, Unix)<br>
**libturbojpeg.0.2.0.dylib** (Mac)<br>
**cygturbojpeg-0.dll** (Cygwin)<br>
Shared library for the TurboJPEG API

**libturbojpeg.so** (Linux, Unix)<br>
**libturbojpeg.dylib** (Mac)<br>
Development symlink for the TurboJPEG API

**libturbojpeg.dll.a** (Cygwin)<br>
Import library for the TurboJPEG API


### Visual C++ (Command Line)

    cd {build_directory}
    cmake -G"NMake Makefiles" -DCMAKE_BUILD_TYPE=Release [additional CMake flags] {source_directory}
    nmake

This will build either a 32-bit or a 64-bit version of libjpeg-turbo, depending
on which version of **cl.exe** is in the `PATH`.

The following files will be generated under *{build_directory}*:

**jpeg-static.lib**<br>
Static link library for the libjpeg API

**jpeg{version}.dll**<br>
DLL for the libjpeg API

**jpeg.lib**<br>
Import library for the libjpeg API

**turbojpeg-static.lib**<br>
Static link library for the TurboJPEG API

**turbojpeg.dll**<br>
DLL for the TurboJPEG API

**turbojpeg.lib**<br>
Import library for the TurboJPEG API

*{version}* is 62, 7, or 8, depending on whether libjpeg v6b (default), v7, or
v8 emulation is enabled.


### Visual C++ (IDE)

Choose the appropriate CMake generator option for your version of Visual Studio
(run `cmake` with no arguments for a list of available generators.)  For
instance:

    cd {build_directory}
    cmake -G"Visual Studio 10" [additional CMake flags] {source_directory}

NOTE: Add "Win64" to the generator name (for example, "Visual Studio 10 Win64")
to build a 64-bit version of libjpeg-turbo.  A separate build directory must be
used for 32-bit and 64-bit builds.

You can then open **ALL_BUILD.vcproj** in Visual Studio and build one of the
configurations in that project ("Debug", "Release", etc.) to generate a full
build of libjpeg-turbo.

This will generate the following files under *{build_directory}*:

**{configuration}/jpeg-static.lib**<br>
Static link library for the libjpeg API

**{configuration}/jpeg{version}.dll**<br>
DLL for the libjpeg API

**{configuration}/jpeg.lib**<br>
Import library for the libjpeg API

**{configuration}/turbojpeg-static.lib**<br>
Static link library for the TurboJPEG API

**{configuration}/turbojpeg.dll**<br>
DLL for the TurboJPEG API

**{configuration}/turbojpeg.lib**<br>
Import library for the TurboJPEG API

*{configuration}* is Debug, Release, RelWithDebInfo, or MinSizeRel, depending
on the configuration you built in the IDE, and *{version}* is 62, 7, or 8,
depending on whether libjpeg v6b (default), v7, or v8 emulation is enabled.


### MinGW

NOTE: This assumes that you are building on a Windows machine using the MSYS
environment.  If you are cross-compiling on a Un*x platform (including Mac and
Cygwin), then see "Build Recipes" below.

    cd {build_directory}
    cmake -G"MSYS Makefiles" [additional CMake flags] {source_directory}
    make

This will generate the following files under *{build_directory}*:

**libjpeg.a**<br>
Static link library for the libjpeg API

**libjpeg-{version}.dll**<br>
DLL for the libjpeg API

**libjpeg.dll.a**<br>
Import library for the libjpeg API

**libturbojpeg.a**<br>
Static link library for the TurboJPEG API

**libturbojpeg.dll**<br>
DLL for the TurboJPEG API

**libturbojpeg.dll.a**<br>
Import library for the TurboJPEG API

*{version}* is 62, 7, or 8, depending on whether libjpeg v6b (default), v7, or
v8 emulation is enabled.


### Debug Build

Add `-DCMAKE_BUILD_TYPE=Debug` to the CMake command line.  Or, if building
with NMake, remove `-DCMAKE_BUILD_TYPE=Release` (Debug builds are the default
with NMake.)


### libjpeg v7 or v8 API/ABI Emulation

Add `-DWITH_JPEG7=1` to the CMake command line to build a version of
libjpeg-turbo that is API/ABI-compatible with libjpeg v7.  Add `-DWITH_JPEG8=1`
to the CMake command line to build a version of libjpeg-turbo that is
API/ABI-compatible with libjpeg v8.  See [README.md](README.md) for more
information about libjpeg v7 and v8 emulation.


### In-Memory Source/Destination Managers

When using libjpeg v6b or v7 API/ABI emulation, add `-DWITH_MEM_SRCDST=0` to
the CMake command line to build a version of libjpeg-turbo that lacks the
`jpeg_mem_src()` and `jpeg_mem_dest()` functions.  These functions were not
part of the original libjpeg v6b and v7 APIs, so removing them ensures strict
conformance with those APIs.  See [README.md](README.md) for more information.


### Arithmetic Coding Support

Since the patent on arithmetic coding has expired, this functionality has been
included in this release of libjpeg-turbo.  libjpeg-turbo's implementation is
based on the implementation in libjpeg v8, but it works when emulating libjpeg
v7 or v6b as well.  The default is to enable both arithmetic encoding and
decoding, but those who have philosophical objections to arithmetic coding can
add `-DWITH_ARITH_ENC=0` or `-DWITH_ARITH_DEC=0` to the CMake command line to
disable encoding or decoding (respectively.)


### TurboJPEG Java Wrapper

Add `-DWITH_JAVA=1` to the CMake command line to incorporate an optional Java
Native Interface (JNI) wrapper into the TurboJPEG shared library and build the
Java front-end classes to support it.  This allows the TurboJPEG shared library
to be used directly from Java applications.  See [java/README](java/README) for
more details.

If Java is not in your `PATH`, or if you wish to use an alternate JDK to
build/test libjpeg-turbo, then (prior to running CMake) set the `JAVA_HOME`
environment variable to the location of the JDK that you wish to use.  The
`Java_JAVAC_EXECUTABLE`, `Java_JAVA_EXECUTABLE`, and `Java_JAR_EXECUTABLE`
CMake variables can also be used to specify alternate commands or locations for
javac, jar, and java (respectively.)  You can also set the
`CMAKE_JAVA_COMPILE_FLAGS` CMake variable or the `JAVAFLAGS` environment
variable to specify arguments that should be passed to the Java compiler when
building the TurboJPEG classes, and the `JAVAARGS` CMake variable to specify
arguments that should be passed to the JRE when running the TurboJPEG Java unit
tests.


Build Recipes
-------------


### 32-bit Build on 64-bit Linux/Unix

Use export/setenv to set the following environment variables before running
CMake:

    CFLAGS=-m32
    LDFLAGS=-m32


### 64-bit Build on Solaris

Use export/setenv to set the following environment variables before running
CMake:

    CFLAGS=-m64
    LDFLAGS=-m64


### Other Compilers

On Un*x systems, prior to running CMake, you can set the `CC` environment
variable to the command used to invoke the C compiler.


### 32-bit MinGW Build on Un*x (including Mac and Cygwin)

Create a file called **toolchain.cmake** under *{build_directory}*, with the
following contents:

    set(CMAKE_SYSTEM_NAME Windows)
    set(CMAKE_SYSTEM_PROCESSOR X86)
    set(CMAKE_C_COMPILER {mingw_binary_path}/i686-w64-mingw32-gcc)
    set(CMAKE_RC_COMPILER {mingw_binary_path}/i686-w64-mingw32-windres)

*{mingw\_binary\_path}* is the directory under which the MinGW binaries are
located (usually **/usr/bin**.)  Next, execute the following commands:

    cd {build_directory}
    cmake -G"Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake \
      -DCMAKE_INSTALL_PREFIX={install_path} \
      [additional CMake flags] {source_directory}
    make

*{install\_path}* is the path under which the libjpeg-turbo binaries should be
installed.


### 64-bit MinGW Build on Un*x (including Mac and Cygwin)

Create a file called **toolchain.cmake** under *{build_directory}*, with the
following contents:

    set(CMAKE_SYSTEM_NAME Windows)
    set(CMAKE_SYSTEM_PROCESSOR AMD64)
    set(CMAKE_C_COMPILER {mingw_binary_path}/x86_64-w64-mingw32-gcc)
    set(CMAKE_RC_COMPILER {mingw_binary_path}/x86_64-w64-mingw32-windres)

*{mingw\_binary\_path}* is the directory under which the MinGW binaries are
located (usually **/usr/bin**.)  Next, execute the following commands:

    cd {build_directory}
    cmake -G"Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake \
      -DCMAKE_INSTALL_PREFIX={install_path} \
      [additional CMake flags] {source_directory}
    make

*{install\_path}* is the path under which the libjpeg-turbo binaries should be
installed.


Building libjpeg-turbo for iOS
------------------------------

iOS platforms, such as the iPhone and iPad, use Arm processors, and all
currently supported models include Neon instructions.  Thus, they can take
advantage of libjpeg-turbo's SIMD extensions to significantly accelerate JPEG
compression/decompression.  This section describes how to build libjpeg-turbo
for these platforms.


### Armv8 (64-bit)

**Xcode 5 or later required, Xcode 6.3.x or later recommended**

The following script demonstrates how to build libjpeg-turbo to run on the
iPhone 5S/iPad Mini 2/iPad Air and newer.

    IOS_PLATFORMDIR=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform
    IOS_SYSROOT=($IOS_PLATFORMDIR/Developer/SDKs/iPhoneOS*.sdk)
    export CFLAGS="-Wall -arch arm64 -miphoneos-version-min=8.0 -funwind-tables"

    cd {build_directory}

    cat <<EOF >toolchain.cmake
    set(CMAKE_SYSTEM_NAME Darwin)
    set(CMAKE_SYSTEM_PROCESSOR aarch64)
    set(CMAKE_C_COMPILER /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang)
    EOF

    cmake -G"Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake \
      -DCMAKE_OSX_SYSROOT=${IOS_SYSROOT[0]} \
      [additional CMake flags] {source_directory}
    make

Replace `iPhoneOS` with `iPhoneSimulator` and `-miphoneos-version-min` with
`-miphonesimulator-version-min` to build libjpeg-turbo for the iOS simulator on
Macs with Apple silicon CPUs.


Building libjpeg-turbo for Android
----------------------------------

Building libjpeg-turbo for Android platforms requires v13b or later of the
[Android NDK](https://developer.android.com/tools/sdk/ndk).


### Armv7 (32-bit)

**NDK r19 or later with Clang recommended**

The following is a general recipe script that can be modified for your specific
needs.

    # Set these variables to suit your needs
    NDK_PATH={full path to the NDK directory-- for example,
      /opt/android/android-ndk-r16b}
    TOOLCHAIN={"gcc" or "clang"-- "gcc" must be used with NDK r16b and earlier,
      and "clang" must be used with NDK r17c and later}
    ANDROID_VERSION={the minimum version of Android to support-- for example,
      "16", "19", etc.}

    cd {build_directory}
    cmake -G"Unix Makefiles" \
      -DANDROID_ABI=armeabi-v7a \
      -DANDROID_ARM_MODE=arm \
      -DANDROID_PLATFORM=android-${ANDROID_VERSION} \
      -DANDROID_TOOLCHAIN=${TOOLCHAIN} \
      -DCMAKE_ASM_FLAGS="--target=arm-linux-androideabi${ANDROID_VERSION}" \
      -DCMAKE_TOOLCHAIN_FILE=${NDK_PATH}/build/cmake/android.toolchain.cmake \
      [additional CMake flags] {source_directory}
    make


### Armv8 (64-bit)

**Clang recommended**

The following is a general recipe script that can be modified for your specific
needs.

    # Set these variables to suit your needs
    NDK_PATH={full path to the NDK directory-- for example,
      /opt/android/android-ndk-r16b}
    TOOLCHAIN={"gcc" or "clang"-- "gcc" must be used with NDK r14b and earlier,
      and "clang" must be used with NDK r17c and later}
    ANDROID_VERSION={the minimum version of Android to support.  "21" or later
      is required for a 64-bit build.}

    cd {build_directory}
    cmake -G"Unix Makefiles" \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_ARM_MODE=arm \
      -DANDROID_PLATFORM=android-${ANDROID_VERSION} \
      -DANDROID_TOOLCHAIN=${TOOLCHAIN} \
      -DCMAKE_ASM_FLAGS="--target=aarch64-linux-android${ANDROID_VERSION}" \
      -DCMAKE_TOOLCHAIN_FILE=${NDK_PATH}/build/cmake/android.toolchain.cmake \
      [additional CMake flags] {source_directory}
    make


### x86 (32-bit)

The following is a general recipe script that can be modified for your specific
needs.

    # Set these variables to suit your needs
    NDK_PATH={full path to the NDK directory-- for example,
      /opt/android/android-ndk-r16b}
    TOOLCHAIN={"gcc" or "clang"-- "gcc" must be used with NDK r14b and earlier,
      and "clang" must be used with NDK r17c and later}
    ANDROID_VERSION={The minimum version of Android to support-- for example,
      "16", "19", etc.}

    cd {build_directory}
    cmake -G"Unix Makefiles" \
      -DANDROID_ABI=x86 \
      -DANDROID_PLATFORM=android-${ANDROID_VERSION} \
      -DANDROID_TOOLCHAIN=${TOOLCHAIN} \
      -DCMAKE_TOOLCHAIN_FILE=${NDK_PATH}/build/cmake/android.toolchain.cmake \
      [additional CMake flags] {source_directory}
    make


### x86-64 (64-bit)

The following is a general recipe script that can be modified for your specific
needs.

    # Set these variables to suit your needs
    NDK_PATH={full path to the NDK directory-- for example,
      /opt/android/android-ndk-r16b}
    TOOLCHAIN={"gcc" or "clang"-- "gcc" must be used with NDK r14b and earlier,
      and "clang" must be used with NDK r17c and later}
    ANDROID_VERSION={the minimum version of Android to support.  "21" or later
      is required for a 64-bit build.}

    cd {build_directory}
    cmake -G"Unix Makefiles" \
      -DANDROID_ABI=x86_64 \
      -DANDROID_PLATFORM=android-${ANDROID_VERSION} \
      -DANDROID_TOOLCHAIN=${TOOLCHAIN} \
      -DCMAKE_TOOLCHAIN_FILE=${NDK_PATH}/build/cmake/android.toolchain.cmake \
      [additional CMake flags] {source_directory}
    make


Advanced CMake Options
----------------------

To list and configure other CMake options not specifically mentioned in this
guide, run

    ccmake {source_directory}

or

    cmake-gui {source_directory}

from the build directory after initially configuring the build.  CCMake is a
text-based interactive version of CMake, and CMake-GUI is a GUI version.  Both
will display all variables that are relevant to the libjpeg-turbo build, their
current values, and a help string describing what they do.


Installing libjpeg-turbo
========================

You can use the build system to install libjpeg-turbo (as opposed to creating
an installer package.)  To do this, run `make install` or `nmake install`
(or build the "install" target in the Visual Studio IDE.)  Running
`make uninstall` or `nmake uninstall` (or building the "uninstall" target in
the Visual Studio IDE) will uninstall libjpeg-turbo.

The `CMAKE_INSTALL_PREFIX` CMake variable can be modified in order to install
libjpeg-turbo into a directory of your choosing.  If you don't specify
`CMAKE_INSTALL_PREFIX`, then the default is:

**c:\libjpeg-turbo**<br>
Visual Studio 32-bit build

**c:\libjpeg-turbo64**<br>
Visual Studio 64-bit build

**c:\libjpeg-turbo-gcc**<br>
MinGW 32-bit build

**c:\libjpeg-turbo-gcc64**<br>
MinGW 64-bit build

**/opt/libjpeg-turbo**<br>
Un*x

The default value of `CMAKE_INSTALL_PREFIX` causes the libjpeg-turbo files to
be installed with a directory structure resembling that of the official
libjpeg-turbo binary packages.  Changing the value of `CMAKE_INSTALL_PREFIX`
(for instance, to **/usr/local**) causes the libjpeg-turbo files to be
installed with a directory structure that conforms to GNU standards.

The `CMAKE_INSTALL_BINDIR`, `CMAKE_INSTALL_DATAROOTDIR`,
`CMAKE_INSTALL_DOCDIR`, `CMAKE_INSTALL_INCLUDEDIR`, `CMAKE_INSTALL_JAVADIR`,
`CMAKE_INSTALL_LIBDIR`, and `CMAKE_INSTALL_MANDIR` CMake variables allow a
finer degree of control over where specific files in the libjpeg-turbo
distribution should be installed.  These directory variables can either be
specified as absolute paths or as paths relative to `CMAKE_INSTALL_PREFIX` (for
instance, setting `CMAKE_INSTALL_DOCDIR` to **doc** would cause the
documentation to be installed in **${CMAKE\_INSTALL\_PREFIX}/doc**.)  If a
directory variable contains the name of another directory variable in angle
brackets, then its final value will depend on the final value of that other
variable.  For instance, the default value of `CMAKE_INSTALL_MANDIR` is
**\<CMAKE\_INSTALL\_DATAROOTDIR\>/man**.

NOTE: If setting one of these directory variables to a relative path using the
CMake command line, you must specify that the variable is of type `PATH`.
For example:

    cmake -G"{generator type}" -DCMAKE_INSTALL_LIBDIR:PATH=lib {source_directory}

Otherwise, CMake will assume that the path is relative to the build directory
rather than the install directory.


Creating Distribution Packages
==============================

The following commands can be used to create various types of distribution
packages:


Linux
-----

    make rpm

Create Red Hat-style binary RPM package.  Requires RPM v4 or later.

    make srpm

This runs `make dist` to create a pristine source tarball, then creates a
Red Hat-style source RPM package from the tarball.  Requires RPM v4 or later.

    make deb

Create Debian-style binary package.  Requires dpkg.


Mac
---

    make dmg

Create Mac package/disk image.  This requires pkgbuild and productbuild, which
are installed by default on OS X/macOS 10.7 and later.

In order to create a Mac package/disk image that contains universal
x86-64/Arm binaries, set the following CMake variable:

* `ARMV8_BUILD`: Directory containing an Armv8 (64-bit) iOS or macOS build of
  libjpeg-turbo to include in the universal binaries

You should first use CMake to configure an Armv8 sub-build of libjpeg-turbo
(see "Building libjpeg-turbo for iOS" above, if applicable) in a build
directory that matches the one specified in the aforementioned CMake variable.
Next, configure the primary (x86-64) build of libjpeg-turbo as an out-of-tree
build, specifying the aforementioned CMake variable, and build it.  Once the
primary build has been built, run `make dmg` from the build directory.  The
packaging system will build the sub-build, use lipo to combine it with the
primary build into a single set of universal binaries, then package the
universal binaries.


Windows
-------

If using NMake:

    cd {build_directory}
    nmake installer

If using MinGW:

    cd {build_directory}
    make installer

If using the Visual Studio IDE, build the "installer" target.

The installer package (libjpeg-turbo-*{version}*[-gcc|-vc][64].exe) will be
located under *{build_directory}*.  If building using the Visual Studio IDE,
then the installer package will be located in a subdirectory with the same name
as the configuration you built (such as *{build_directory}*\Debug\ or
*{build_directory}*\Release\).

Building a Windows installer requires the
[Nullsoft Install System](http://nsis.sourceforge.net/).  makensis.exe should
be in your `PATH`.


Regression testing
==================

The most common way to test libjpeg-turbo is by invoking `make test` (Un*x) or
`nmake test` (Windows command line) or by building the "RUN_TESTS" target
(Visual Studio IDE), once the build has completed.  This runs a series of tests
to ensure that mathematical compatibility has been maintained between
libjpeg-turbo and libjpeg v6b.  This also invokes the TurboJPEG unit tests,
which ensure that the colorspace extensions, YUV encoding, decompression
scaling, and other features of the TurboJPEG C and Java APIs are working
properly (and, by extension, that the equivalent features of the underlying
libjpeg API are also working.)

Invoking `make testclean` (Un*x) or `nmake testclean` (Windows command line) or
building the "testclean" target (Visual Studio IDE) will clean up the output
images generated by the tests.

On Un*x platforms, more extensive tests of the TurboJPEG C and Java wrappers
can be run by invoking `make tjtest`.  These extended TurboJPEG tests
essentially iterate through all of the available features of the TurboJPEG APIs
that are not covered by the TurboJPEG unit tests (including the lossless
transform options) and compare the images generated by each feature to images
generated using the equivalent feature in the libjpeg API.  The extended
TurboJPEG tests are meant to test for regressions in the TurboJPEG wrappers,
not in the underlying libjpeg API library.
