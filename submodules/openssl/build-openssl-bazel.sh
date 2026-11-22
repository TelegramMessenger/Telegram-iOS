#!/bin/bash

set -x
set -e

OUT_DIR="$1"
SRC_DIR="$2"
ARCH="$3"

if [ "$ARCH" != "arm64" ] && [ "$ARCH" != "armv7" ] && [ "$ARCH" != "x86_64" ]; then
  echo "Invalid architecture $ARCH"
  exit 1
fi

if [ -z "$OUT_DIR" ]; then
  echo "Usage: sh build-openssl.sh OUT_DIR SRC_DIR ARCH"
  exit 1
fi

if [ -z "$SRC_DIR" ]; then
  echo "Usage: sh build-openssl.sh OUT_DIR SRC_DIR ARCH"
  exit 1
fi

if [ ! -d "$SRC_DIR" ]; then
  echo "$SRC_DIR does not exist"
  exit 1
fi

mkdir -p "$OUT_DIR"

TMP_DIR_NAME="build"
TMP_DIR="$OUT_DIR/$TMP_DIR_NAME"
ABS_TMP_DIR="$(pwd)/$TMP_DIR"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

CROSS_TOP_SIM="`xcode-select --print-path`/Platforms/iPhoneSimulator.platform/Developer"
CROSS_SDK_SIM="iPhoneSimulator.sdk"

CROSS_TOP_IOS="`xcode-select --print-path`/Platforms/iPhoneOS.platform/Developer"
CROSS_SDK_IOS="iPhoneOS.sdk"

SOURCE_DIR="$OUT_DIR/openssl-1.1.1d"
SOURCE_ARCHIVE="$SRC_DIR/openssl-1.1.1d.tar.gz"

rm -rf "$SOURCE_DIR"

tar -xzf "$SOURCE_ARCHIVE" --directory "$OUT_DIR"

export CROSS_COMPILE=`xcode-select --print-path`/Toolchains/XcodeDefault.xctoolchain/usr/bin/

function build_for ()
{
  DIR="$(pwd)"
  cd "$SOURCE_DIR"

  PLATFORM="$1"
  ARCH="$2"
  CROSS_TOP_ENV="CROSS_TOP_$3"
  CROSS_SDK_ENV="CROSS_SDK_$3"

  make clean

  export CROSS_TOP="${!CROSS_TOP_ENV}"
  export CROSS_SDK="${!CROSS_SDK_ENV}"

  MINIMAL_FLAGS=(\
    "no-shared" \
    "no-afalgeng" \
    "no-aria" \
    "no-asan" \
    "no-async" \
    "no-autoalginit" \
    "no-autoerrinit" \
    "no-autoload-config" \
    "no-bf" \
    "no-blake2" \
    "no-buildtest-c++" \
    "no-camellia" \
    "no-capieng" \
    "no-cast" \
    "no-chacha" \
    "no-cmac" \
    "no-cms" \
    "no-comp" \
    "no-crypto-mdebug" \
    "no-crypto-mdebug-backtrace" \
    "no-ct" \
    "no-deprecated" \
    "no-des" \
    "no-devcryptoeng" \
    "no-dgram" \
    "no-dh" \
    "no-dsa" \
    "no-dtls" \
    "no-dynamic-engine" \
    "no-ec" \
    "no-ec2m" \
    "no-ecdh" \
    "no-ecdsa" \
    "no-ec_nistp_64_gcc_128" \
    "no-egd" \
    "no-engine" \
    "no-err" \
    "no-external-tests" \
    "no-filenames" \
    "no-fuzz-libfuzzer" \
    "no-fuzz-afl" \
    "no-gost" \
    "no-heartbeats" \
    "no-idea" \
    "no-makedepend" \
    "no-md2" \
    "no-md4" \
    "no-mdc2" \
    "no-msan" \
    "no-multiblock" \
    "no-nextprotoneg" \
    "no-pinshared" \
    "no-ocb" \
    "no-ocsp" \
    "no-pic" \
    "no-poly1305" \
    "no-posix-io" \
    "no-psk" \
    "no-rc2" \
    "no-rc4" \
    "no-rc5" \
    "no-rfc3779" \
    "no-rmd160" \
    "no-scrypt" \
    "no-sctp" \
    "no-shared" \
    "no-siphash" \
    "no-sm2" \
    "no-sm3" \
    "no-sm4" \
    "no-sock" \
    "no-srp" \
    "no-srtp" \
    "no-sse2" \
    "no-ssl" \
    "no-ssl-trace" \
    "no-static-engine" \
    "no-stdio" \
    "no-tests" \
    "no-tls" \
    "no-ts" \
    "no-ubsan" \
    "no-ui-console" \
    "no-unit-test" \
    "no-whirlpool" \
    "no-weak-ssl-ciphers" \
    "no-zlib" \
    "no-zlib-dynamic" \
  )

  DEFAULT_FLAGS=(\
    "no-shared" \
    "no-asm" \
    "no-ssl3" \
    "no-comp" \
    "no-hw" \
    "no-engine" \
    "no-async" \
    "no-tests" \
  )

  ./Configure $PLATFORM "-arch $ARCH" ${DEFAULT_FLAGS[@]} --prefix="${ABS_TMP_DIR}/${ARCH}" || exit 1
  
  make && make install_sw || exit 2
  unset CROSS_TOP
  unset CROSS_SDK

  cd "$DIR"
}

patch "$SOURCE_DIR/Configurations/10-main.conf" < "$SRC_DIR/patch-conf.patch" || exit 1

if [ "$ARCH" == "x86_64" ]; then
  build_for ios64sim-cross x86_64 SIM || exit 2
elif [ "$ARCH" == "armv7" ]; then
  build_for ios-cross armv7 IOS || exit 4
elif [ "$ARCH" == "arm64" ]; then
  build_for ios64-cross arm64 IOS || exit 5
else
  echo "Invalid architecture $ARCH"
  exit 1
fi

cp -r "${TMP_DIR}/$ARCH/include" "${TMP_DIR}/"
if [ "$ARCH" == "arm64" ]; then
  patch -p3 "${TMP_DIR}/include/openssl/opensslconf.h" < "$SRC_DIR/patch-include.patch" || exit 1
fi

DFT_DIST_DIR="$OUT_DIR/out"
rm -rf "$DFT_DIST_DIR"
mkdir -p "$DFT_DIST_DIR"

DIST_DIR="${DIST_DIR:-$DFT_DIST_DIR}"
mkdir -p "${DIST_DIR}"
cp -r "${TMP_DIR}/include" "${TMP_DIR}/$ARCH/lib" "${DIST_DIR}"