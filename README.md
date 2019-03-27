[![Build Status](https://travis-ci.org/Samsung/rlottie.svg?branch=master)](https://travis-ci.org/Samsung/rlottie)

# rlottie
A platform independent standalone library that plays Lottie Animation.

## BUILD INSTRUCTIONS

1. install meson build system. ( follow instruction in this link http://mesonbuild.com/Getting-meson.html )
2. install ninja build tool    (https://ninja-build.org/)
3. invoke meson build/  or meson -Dexample=true build/
4. invoke ninja inside the build folder.

NOTE: run meson configure to see all the build options

## BUILD EXAMPLES

1. meson configure -Dexample=true
2. ninja
3. to run examples invoke ./build/example/demo, etc.

## RUN TESTS

1. meson configure -Dtest=true
2. ninja
3. invoke testsuites as ./build/test/animationTestSuite and ./build/test/vectorTestSuite

## BUILD WITH CMAKE

librlottie can also be built using the cmake build system.

1. install cmake.  (Follow instructions at https://cmake.org/download/)
2. create a new build/ directory
3. invoke cmake from inside build/ as cmake -DLIB_INSTALL_DIR=lib ..
4. invoke make
5. invoke sudo make install to install, if desired.

To install to a different prefix, specify it when running cmake, e.g.:
 cmake -DCMAKE_INSTALL_PREFIX:PATH=~/Build -DLIB_INSTALL_DIR=~/Build/lib ..
