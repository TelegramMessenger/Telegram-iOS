#! /bin/sh

set -e

ARCH="$1"

SOURCE_DIR="$2"
BUILD_DIR=$(echo "$(cd "$(dirname "$3")"; pwd -P)/$(basename "$3")")

RSSS="9"

CMAKE_OPTIONS="-DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DJPEGXL_ENABLE_BENCHMARK=0 -DJPEGXL_ENABLE_FUZZERS=0 -DJPEGXL_ENABLE_TOOLS=0 -DJPEGXL_ENABLE_JPEGLI=0 -DJPEGXL_ENABLE_DOXYGEN=0 -DJPEGXL_ENABLE_MANPAGES=0 -DJPEGXL_ENABLE_BENCHMARK=0 -DJPEGXL_ENABLE_EXAMPLES=0 -DJPEGXL_BUNDLE_LIBPNG=0 -DJPEGXL_ENABLE_JNI=0 -DJPEGXL_ENABLE_SJPEG=0 -DJPEGXL_ENABLE_OPENEXR=0 -DJPEGXL_ENABLE_TRANSCODE_JPEG=0 -DJPEGXL_STATIC=1 -DJPEGXL_ENABLE_BOXES=0"

if [ "$ARCH" = "arm64" ]; then
  IOS_PLATFORMDIR="$(xcode-select -p)/Platforms/iPhoneOS.platform"
  IOS_SYSROOT=($IOS_PLATFORMDIR/Developer/SDKs/iPhoneOS*.sdk)
  export CFLAGS="-Wall -arch arm64 -miphoneos-version-min=13.0 -funwind-tables"
  export CXXFLAGS="$CFLAGS"

  cd "$BUILD_DIR"
  mkdir build
  cd build

  touch toolchain.cmake
  echo "set(CMAKE_SYSTEM_NAME Darwin)" >> toolchain.cmake
  echo "set(CMAKE_SYSTEM_PROCESSOR aarch64)" >> toolchain.cmake
  echo "set(CMAKE_C_COMPILER $(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang)" >> toolchain.cmake

  cmake -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake -DCMAKE_OSX_SYSROOT=${IOS_SYSROOT[0]} $CMAKE_OPTIONS ../libjxl
  make
elif [ "$ARCH" = "sim_arm64" ]; then
  IOS_PLATFORMDIR="$(xcode-select -p)/Platforms/iPhoneSimulator.platform"
  IOS_SYSROOT=($IOS_PLATFORMDIR/Developer/SDKs/iPhoneSimulator*.sdk)
  export CFLAGS="-Wall -arch arm64 --target=arm64-apple-ios13.0-simulator -miphonesimulator-version-min=13.0 -funwind-tables"
  export CXXFLAGS="$CFLAGS"
  
  cd "$BUILD_DIR"
  mkdir build
  cd build

  touch toolchain.cmake
  echo "set(CMAKE_SYSTEM_NAME Darwin)" >> toolchain.cmake
  echo "set(CMAKE_SYSTEM_PROCESSOR aarch64)" >> toolchain.cmake
  echo "set(CMAKE_C_COMPILER $(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang)" >> toolchain.cmake

  cmake -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake -DCMAKE_OSX_SYSROOT=${IOS_SYSROOT[0]} $CMAKE_OPTIONS ../libjxl
  make
elif [ "$ARCH" = "x86_64" ]; then
  IOS_PLATFORMDIR="$(xcode-select -p)/Platforms/iPhoneSimulator.platform"
  IOS_SYSROOT=($IOS_PLATFORMDIR/Developer/SDKs/iPhoneSimulator*.sdk)
  export CFLAGS="-Wall -arch x86_64 -miphoneos-version-min=13.0 -funwind-tables"
  export CXXFLAGS="$CFLAGS"
  
  cd "$BUILD_DIR"
  mkdir build
  cd build

  touch toolchain.cmake
  echo "set(CMAKE_SYSTEM_NAME Darwin)" >> toolchain.cmake
  echo "set(CMAKE_SYSTEM_PROCESSOR AMD64)" >> toolchain.cmake
  echo "set(CMAKE_C_COMPILER $(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang)" >> toolchain.cmake

  cmake -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake -DCMAKE_OSX_SYSROOT=${IOS_SYSROOT[0]} $CMAKE_OPTIONS ../libjxl
  make
else
  echo "Unsupported architecture $ARCH"
  exit 1
fi
