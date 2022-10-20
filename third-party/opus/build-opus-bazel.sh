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

# where we will keep our sources and build from.
SRCDIR="${BUILD_DIR}/src"
mkdir -p $SRCDIR
# where we will store intermediary builds
INTERDIR="${BUILD_DIR}/built"
mkdir -p $INTERDIR

########################################

tar zxf "$BUILD_DIR/$SOURCE_CODE_ARCHIVE" -C $SRCDIR
cd "${SRCDIR}/opus-"*

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

SDK_PATH="$(xcrun --sdk $PLATFORM --show-sdk-path 2>/dev/null)"

mkdir -p "${INTERDIR}"

./configure --enable-float-approx --disable-shared --enable-static --with-pic --disable-extra-programs --disable-doc ${EXTRA_CONFIG} \
  --prefix="${INTERDIR}" \
  LDFLAGS="$LDFLAGS ${OPT_LDFLAGS} -fPIE -miphoneos-version-min=${MINIOSVERSION} -L${OUTPUTDIR}/lib" \
  CFLAGS="$CFLAGS ${EXTRA_CFLAGS} ${OPT_CFLAGS} -fPIE -miphoneos-version-min=${MINIOSVERSION} -I${OUTPUTDIR}/include -isysroot ${SDK_PATH}" \

make -j
make install
