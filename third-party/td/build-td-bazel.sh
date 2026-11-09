#!/bin/sh

set -e
set -x

# The Bazel genrule environment only exposes /bin:/usr/bin:/usr/local/bin,
# while some tools we rely on (for example sysctl) live in /usr/sbin.
PATH="$PATH:/usr/sbin:/sbin"
export PATH

ARCH="$1"

SOURCE_DIR="$2"
BUILD_DIR=$(echo "$(cd "$(dirname "$3")"; pwd -P)/$(basename "$3")")
OPENSSL_DIR="$4"

# Pick a safe job count. sysctl may be missing inside the genrule sandbox, so
# fall back to getconf and finally to a fixed value. The cap keeps memory usage
# reasonable because Bazel runs other actions in parallel.
JOBS=$(/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || true)
case "$JOBS" in
  ''|*[!0-9]*) JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || true) ;;
esac
case "$JOBS" in
  ''|*[!0-9]*) JOBS=4 ;;
esac
if [ "$JOBS" -gt 4 ]; then
  JOBS=4
fi

openssl_crypto_library="${OPENSSL_DIR}/lib/libcrypto.a"
options=""
options="$options -DOPENSSL_FOUND=1"
options="$options -DOPENSSL_CRYPTO_LIBRARY=${openssl_crypto_library}"
options="$options -DOPENSSL_INCLUDE_DIR=${OPENSSL_DIR}/src/include"
options="$options -DCMAKE_BUILD_TYPE=Release"
options="$options -DIOS_DEPLOYMENT_TARGET=13.0"
# ccache is detected by TDLib's CMake but is not usable from this environment,
# so force it off for every configuration.
options="$options -DCCACHE_FOUND=0"

cd "$BUILD_DIR"

# Generate source files
mkdir native-build
cd native-build
cmake -DTD_GENERATE_SOURCE_FILES=ON -DCCACHE_FOUND=0 ../td
cmake --build . -- -j"$JOBS"
cd ..

if [ "$ARCH" = "arm64" ]; then
  IOS_PLATFORMDIR="$(xcode-select -p)/Platforms/iPhoneOS.platform"
  IOS_SYSROOT=($IOS_PLATFORMDIR/Developer/SDKs/iPhoneOS*.sdk)
  export CFLAGS="-arch arm64 --target=arm64-apple-ios13.0 -miphoneos-version-min=13.0 -w"
elif [ "$ARCH" = "sim_arm64" ]; then
  IOS_PLATFORMDIR="$(xcode-select -p)/Platforms/iPhoneSimulator.platform"
  IOS_SYSROOT=($IOS_PLATFORMDIR/Developer/SDKs/iPhoneSimulator*.sdk)
  export CFLAGS="-arch arm64 --target=arm64-apple-ios13.0-simulator -miphonesimulator-version-min=13.0 -w"
elif [ "$ARCH" = "macos_arm64" ]; then
  IOS_PLATFORMDIR="$(xcode-select -p)/Platforms/MacOSX.platform"
  IOS_SYSROOT=($IOS_PLATFORMDIR/Developer/SDKs/MacOSX*.sdk)
  export CFLAGS="-arch arm64 --target=arm64-apple-macosx14.0 -mmacosx-version-min=14.0 -w"
else
  echo "Unsupported architecture $ARCH"
  exit 1
fi
export CXXFLAGS="$CFLAGS"

# Common build steps
mkdir build
cd build

touch toolchain.cmake
echo "set(CMAKE_SYSTEM_NAME Darwin)" >> toolchain.cmake
echo "set(CMAKE_SYSTEM_PROCESSOR aarch64)" >> toolchain.cmake
echo "set(CMAKE_C_COMPILER $(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang)" >> toolchain.cmake

cmake -G"Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake -DCMAKE_OSX_SYSROOT=${IOS_SYSROOT[0]} ../td $options
make tde2e -j"$JOBS"
