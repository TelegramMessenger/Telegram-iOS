#!/bin/sh
cd $(dirname $0)
td_path=$(grealpath ../..)

rm -rf build
mkdir -p build
cd build

set_cmake_options () {
  # Set CMAKE options depending on platform passed $1
  openssl_path=$(grealpath ../third_party/openssl/$1)
  echo "OpenSSL path = ${openssl_path}"
  openssl_crypto_library="${openssl_path}/lib/libcrypto.a"
  openssl_ssl_library="${openssl_path}/lib/libssl.a"
  options=""
  options="$options -DOPENSSL_FOUND=1"
  options="$options -DOPENSSL_CRYPTO_LIBRARY=${openssl_crypto_library}"
  options="$options -DOPENSSL_SSL_LIBRARY=${openssl_ssl_library}"
  options="$options -DOPENSSL_INCLUDE_DIR=${openssl_path}/include"
  options="$options -DOPENSSL_LIBRARIES=${openssl_crypto_library};${openssl_ssl_library}"
  options="$options -DCMAKE_BUILD_TYPE=Release"
}

platforms="macOS iOS watchOS tvOS visionOS"
#platforms="watchOS"
for platform in $platforms;
do
  echo "Platform = ${platform}"
  if [[ $platform = "macOS" ]]; then
    simulators="0"
  else
    simulators="0 1"
  fi

  for simulator in $simulators;
  do
    if [[ $platform = "macOS" ]]; then
      other_options="-DCMAKE_OSX_ARCHITECTURES='x86_64;arm64'"
    else
      if [[ $platform = "watchOS" ]]; then
        ios_platform="WATCH"
      elif [[ $platform = "tvOS" ]]; then
        ios_platform="TV"
      elif [[ $platform = "visionOS" ]]; then
        ios_platform="VISION"
      else
        ios_platform=""
      fi

      if [[ $simulator = "1" ]]; then
        platform="${platform}-simulator"
        ios_platform="${ios_platform}SIMULATOR"
      else
        ios_platform="${ios_platform}OS"
      fi

      echo "iOS platform = ${ios_platform}"
      other_options="-DIOS_PLATFORM=${ios_platform} -DCMAKE_TOOLCHAIN_FILE=${td_path}/CMake/iOS.cmake"
    fi

    set_cmake_options $platform
    build="build-${platform}"
    install="install-${platform}"
    rm -rf $build
    mkdir -p $build
    mkdir -p $install
    cd $build
    cmake $td_path $options $other_options -DCMAKE_INSTALL_PREFIX=../${install}
    make -j3 install || exit
    cd ..
    install_name_tool -id @rpath/libtdjson.dylib ${install}/lib/libtdjson.dylib
    mkdir -p ../tdjson/${platform}/include
    rsync --recursive ${install}/include/ ../tdjson/${platform}/include/
    mkdir -p ../tdjson/${platform}/lib
    cp ${install}/lib/libtdjson.dylib ../tdjson/${platform}/lib/
  done
done

produced_dylibs=(install-*/lib/libtdjson.dylib)
xcodebuild_frameworks=()

for dylib in "${produced_dylibs[@]}";
do
  xcodebuild_frameworks+=(-library $(grealpath "${dylib}"))
done

# Make xcframework
xcodebuild -create-xcframework \
    "${xcodebuild_frameworks[@]}" \
    -output "libtdjson.xcframework"

rsync --recursive libtdjson.xcframework ../tdjson/
