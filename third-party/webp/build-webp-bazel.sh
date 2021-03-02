#! /bin/sh

set -ex

ARCH="$1"
BUILD_DIR=$(echo "$(cd "$(dirname "$2")"; pwd -P)/$(basename "$2")")
SOURCE_CODE_ARCHIVE="$3"

MINIOSVERSION="9.0"

OPT_CFLAGS="-Os -g"
OPT_LDFLAGS=""
OPT_CONFIG_ARGS=""

DEVELOPER=`xcode-select -print-path`

OUTPUTDIR="$BUILD_DIR/Public"

SRCDIR="${BUILD_DIR}/src"
mkdir -p $SRCDIR

tar zxf "$BUILD_DIR/$SOURCE_CODE_ARCHIVE" -C $SRCDIR
cd "${SRCDIR}/libwebp-"*
PREFIX="$(pwd)/build-output"

if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ]; then
  PLATFORM="iphonesimulator"
  EXTRA_CFLAGS="-arch ${ARCH}"
  EXTRA_CONFIG="--host=x86_64-apple-darwin"
elif [ "${ARCH}" == "sim_arm64" ]; then
  PLATFORM="iphonesimulator"
  EXTRA_CFLAGS="-arch arm64 --target=arm64-apple-ios$MINIOSVERSION-simulator"
  EXTRA_CONFIG="--host=arm-apple-darwin20"
else
  PLATFORM="iphoneos"
  EXTRA_CFLAGS="-arch ${ARCH}"
  EXTRA_CONFIG="--host=arm-apple-darwin"
fi

SDKROOT="$(xcrun --sdk $PLATFORM --show-sdk-path 2>/dev/null)"

DEVROOT="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain"

CFLAGS="-pipe -isysroot ${SDKROOT} -O3 -DNDEBUG $EXTRA_CFLAGS"
CFLAGS+=" -miphoneos-version-min=9.0"

PATH="${DEVROOT}/usr/bin:${PATH}" ./configure \
  ${EXTRA_CONFIG} \
  --prefix=${PREFIX} \
  --build=$(./config.guess) \
  --disable-shared --enable-static \
  --disable-libwebpdecoder --enable-swap-16bit-csp \
  CFLAGS="${CFLAGS}"

make V=0
make install
