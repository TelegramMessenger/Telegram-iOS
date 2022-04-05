#! /bin/sh

set -e
set -x

RAW_ARCH="$1"

SOURCE_DIR=$(echo "$(cd "$(dirname "$2")"; pwd -P)/$(basename "$2")")
BUILD_DIR=$(echo "$(cd "$(dirname "$3")"; pwd -P)/$(basename "$3")")

SCRATCH="$BUILD_DIR/scratch"

#set -e
#devnull='> /dev/null 2>&1'

DEPLOYMENT_TARGET="9.0"
CONFIGURE_FLAGS="--enable-static --enable-pic --disable-cli --bit-depth=8 --disable-opencl"

echo "building $RAW_ARCH..."
mkdir -p "$SCRATCH/$RAW_ARCH"
cd "$SCRATCH/$RAW_ARCH"
ASFLAGS=

if [ "$RAW_ARCH" = "i386" -o "$RAW_ARCH" = "x86_64" ]
then
  ARCH="$RAW_ARCH"
  PLATFORM="iPhoneSimulator"
  CPU=""
  CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
  HOST="--host=i386-apple-darwin"
elif [ "$RAW_ARCH" = "sim_arm64" ]; then
  ARCH="arm64"
  PLATFORM="iPhoneSimulator"
  CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET --target=arm64-apple-ios$DEPLOYMENT_TARGET-simulator"
  HOST="--host=aarch64-apple-darwin"
else
  ARCH="$RAW_ARCH"
  PLATFORM="iPhoneOS"
  HOST="--host=aarch64-apple-darwin"
  XARCH="-arch aarch64"
  CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET"
  ASFLAGS="$CFLAGS"
  if [ "$RAW_ARCH" = "arm64" ]
  then
      EXPORT="GASPP_FIX_XCODE5=1"
  fi
fi

CFLAGS="-arch $ARCH"

#if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" -o "$ARCH" = "" ]; then
#    PLATFORM="iPhoneSimulator"
#    CPU=
#    if [ "$ARCH" = "x86_64" ]
#    then
#      CFLAGS="$CFLAGS -mios-simulator-version-min=7.0"
#      HOST=
#    else
#      CFLAGS="$CFLAGS -mios-simulator-version-min=5.0"
#  HOST="--host=i386-apple-darwin"
#    fi
#else
#    PLATFORM="iPhoneOS"
#    if [ $ARCH = "arm64" ]
#    then
#        HOST="--host=aarch64-apple-darwin"
#  XARCH="-arch aarch64"
#    else
#        HOST="--host=arm-apple-darwin"
#  XARCH="-arch arm"
#    fi
#                CFLAGS="$CFLAGS -fembed-bitcode -mios-version-min=7.0"
#                ASFLAGS="$CFLAGS"
#fi

XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
CC="xcrun -sdk $XCRUN_SDK clang"
if [ $PLATFORM = "iPhoneOS" ]
then
    export AS="$SOURCE_DIR/tools/gas-preprocessor.pl $XARCH -- $CC"
else
    export -n AS
fi
CXXFLAGS="$CFLAGS"
LDFLAGS="$CFLAGS"

CC=$CC $SOURCE_DIR/configure $CONFIGURE_FLAGS $HOST --extra-cflags="$CFLAGS" --extra-asflags="$ASFLAGS" --extra-ldflags="$LDFLAGS" --prefix="$SCRATCH/thin" || exit 1

make -j3 install || exit 1
