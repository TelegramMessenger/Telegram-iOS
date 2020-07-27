#/bin/sh

set -x
set -e

BUILD_DIR="$1"
ARCH="$2"

echo "BUILD_DIR=$BUILD_DIR"
echo "ARCH=$ARCH"

export PATH="$PATH:$BUILD_DIR/depot_tools_sources/depot_tools"

rm -rf "$BUILD_DIR/webrtc-ios/src/openssl"
cp -R "$BUILD_DIR/openssl" "$BUILD_DIR/webrtc-ios/src/"
cp -R "$BUILD_DIR/libssl" "$BUILD_DIR/webrtc-ios/src/"

pushd "$BUILD_DIR/webrtc-ios/src"

mv openssl/lib/libcrypto.a openssl/
mv libssl/lib/libssl.a openssl/

OUT_DIR="ios"
if [ "$ARCH" == "arm64" ]; then
  OUT_DIR="ios_64"
elif [ "$ARCH" == "x64" ]; then
  OUT_DIR="ios_sim"
fi

buildtools/mac/gn gen out/$OUT_DIR --args="use_xcode_clang=true "" target_cpu=\"$ARCH\""' target_os="ios" is_debug=false is_component_build=false rtc_include_tests=false use_rtti=true rtc_use_x11=false use_custom_libcxx=false use_custom_libcxx_for_host=false rtc_build_ssl=false rtc_build_examples=false rtc_build_tools=false ios_deployment_target="9.0" ios_enable_code_signing=false is_unsafe_developer_build=false rtc_enable_protobuf=false rtc_include_builtin_video_codecs=true rtc_build_libvpx=true rtc_libvpx_build_vp9=true rtc_use_gtk=false rtc_use_metal_rendering=true'
ninja -C out/$OUT_DIR framework_objc_static

popd
