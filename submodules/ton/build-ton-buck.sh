#/bin/sh

set -x
set -e

OUT_DIR="$1"
SOURCE_DIR="$2"
openssl_base_path="$3"

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
TOOLCHAIN="$SOURCE_DIR/iOS-buck.cmake"

mkdir -p "$OUT_DIR"
mkdir -p "$OUT_DIR/build"
cd "$OUT_DIR/build"

platforms="iOS"
for platform in $platforms; do
  openssl_path="$openssl_base_path"
  echo "OpenSSL path = ${openssl_path}"
  openssl_crypto_library="${openssl_path}/lib/libcrypto.a"
  openssl_ssl_library="${openssl_path}/lib/libssl.a"
  options="$options -DOPENSSL_FOUND=1"
  options="$options -DOPENSSL_CRYPTO_LIBRARY=${openssl_crypto_library}"
  options="$options -DOPENSSL_INCLUDE_DIR=${openssl_path}/include"
  options="$options -DOPENSSL_LIBRARIES=${openssl_crypto_library}"
  options="$options -DCMAKE_BUILD_TYPE=Release"
  if [[ $skip_build = "" ]]; then
    simulators="0 1"
  else
    simulators=""
  fi
  for simulator in $simulators;
  do
    build="build-${platform}"
    install="install-${platform}"
    if [[ $simulator = "1" ]]; then
      build="${build}-simulator"
      install="${install}-simulator"
      ios_platform="SIMULATOR"
    else
      ios_platform="OS"
    fi
    echo "Platform = ${platform} Simulator = ${simulator}"
    echo $ios_platform
    rm -rf $build
    mkdir -p $build
    mkdir -p $install
    cd $build
    cmake $td_path $options -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" -DIOS_PLATFORM=${ios_platform} -DTON_ARCH= -DCMAKE_INSTALL_PREFIX=../${install}
    CORE_COUNT=`sysctl -n hw.logicalcpu`
    make -j$CORE_COUNT install || exit
    cd ..
  done
  mkdir -p $platform

  mkdir -p "out"
  cp -r "install-iOS/include" "out/"
  mkdir -p "out/lib"

  for f in install-iOS/lib/*.a; do
    lib_name=$(basename "$f")
    lipo -create "install-iOS/lib/$lib_name" "install-iOS-simulator/lib/$lib_name" -o "out/lib/$lib_name"
  done
done
