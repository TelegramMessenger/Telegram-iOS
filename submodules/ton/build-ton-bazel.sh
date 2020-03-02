#/bin/sh

set -x
set -e

OUT_DIR="$(pwd)/$1"
SOURCE_DIR="$(pwd)/$2"
openssl_base_path="$(pwd)/$3"
arch="$4"

if [ -z "$openssl_base_path" ]; then
  echo "Usage: sh build-ton.sh path/to/openssl"
  exit 1
fi

if [ ! -d "$openssl_base_path" ]; then
  echo "$openssl_base_path not found"
  exit 1
fi

ARCHIVE_PATH="$SOURCE_DIR/tonlib.zip"
td_path="$SOURCE_DIR/tonlib-src"
TOOLCHAIN="$SOURCE_DIR/iOS-bazel.cmake"

mkdir -p "$OUT_DIR"
mkdir -p "$OUT_DIR/build"
cd "$OUT_DIR/build"

openssl_path="$openssl_base_path"
echo "OpenSSL path = ${openssl_path}"
openssl_crypto_library="${openssl_path}/lib/libcrypto.a"
openssl_ssl_library="${openssl_path}/lib/libssl.a"
options="$options -DOPENSSL_FOUND=1"
options="$options -DOPENSSL_CRYPTO_LIBRARY=${openssl_crypto_library}"
options="$options -DOPENSSL_INCLUDE_DIR=${openssl_path}/include"
options="$options -DOPENSSL_LIBRARIES=${openssl_crypto_library}"
options="$options -DCMAKE_BUILD_TYPE=Release"

build="build-${arch}"
install="install-${arch}"

if [ "$arch" == "armv7" ]; then
  ios_platform="OSV7"
elif [ "$arch" == "arm64" ]; then
  ios_platform="OS64"
elif [ "$arch" == "x86_64" ]; then
  ios_platform="SIMULATOR"
else
  echo "Unsupported architecture $arch"
  exit 1
fi

rm -rf $build
mkdir -p $build
mkdir -p $install
cd $build
cmake $td_path $options -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" -DIOS_PLATFORM=${ios_platform} -DTON_ARCH= -DCMAKE_INSTALL_PREFIX=../${install}
CORE_COUNT=`sysctl -n hw.logicalcpu`
make -j$CORE_COUNT install || exit
cd ..

mkdir -p "out"
cp -r "$install/include" "out/"
mkdir -p "out/lib"

for f in $install/lib/*.a; do
  lib_name=$(basename "$f")
  cp "$install/lib/$lib_name" "out/lib/$lib_name"
done
