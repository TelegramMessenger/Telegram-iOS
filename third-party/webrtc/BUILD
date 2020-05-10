webrtc_libs = [
    "libwebrtc.a",
]

filegroup(
    name = "webrtc_sources",
    srcs = glob([
        "webrtc-ios/**/*"
    ], exclude = [
        "**/.git/**",
    ]),
)

genrule(
    name = "webrtc_build",
    srcs = [
        "build-webrtc-bazel.sh",
        "patch.sh",
        ":webrtc_sources",
        "//third-party:depot_tools_sources",
        "//submodules/openssl:openssl_include",
        "//submodules/openssl:libcrypto.a",
        "//submodules/openssl:libssl.a",
    ],
    cmd_bash =
    """
        OUT_DIR="ios"
        if [ "$(TARGET_CPU)" == "ios_armv7" ]; then
            BUILD_ARCH="armv7"
        elif [ "$(TARGET_CPU)" == "ios_arm64" ]; then
            BUILD_ARCH="arm64"
        elif [ "$(TARGET_CPU)" == "ios_x86_64" ]; then
            BUILD_ARCH="x64"
            OUT_DIR="ios_sim"
        else
            echo "Unsupported architecture $(TARGET_CPU)"
        fi
        BUILD_DIR="$(RULEDIR)/$$BUILD_ARCH"
        #rm -rf "$$BUILD_DIR"
        mkdir -p "$$BUILD_DIR"

        SOURCE_PATH="third-party/webrtc/webrtc-ios/src"

        rsync -aqW "$$SOURCE_PATH" "$$BUILD_DIR/"
        #cp -R "$$SOURCE_PATH" "$$BUILD_DIR/"

        DEPOT_TOOLS_PATH="third-party/depot_tools"

        rm -rf "$$BUILD_DIR/depot_tools"
        cp -R "$$DEPOT_TOOLS_PATH" "$$BUILD_DIR/"

        rm -rf "$$BUILD_DIR/openssl"
        mkdir -p "$$BUILD_DIR/openssl/include/openssl"
        for f in $(locations //submodules/openssl:openssl_include); do
            cp -f "$$f" "$$BUILD_DIR/openssl/include/openssl/"
        done

        mkdir -p "$$BUILD_DIR/openssl/lib"
        cp -f "$(location //submodules/openssl:libcrypto.a)" "$$BUILD_DIR/openssl/"
        cp -f "$(location //submodules/openssl:libssl.a)" "$$BUILD_DIR/openssl/"

        rm -f "$$BUILD_DIR/build-webrtc-bazel.sh"
        cp $(location build-webrtc-bazel.sh) "$$BUILD_DIR/"

        rm -f "$$BUILD_DIR/patch.sh"
        cp $(location patch.sh) "$$BUILD_DIR/"

        sh $$BUILD_DIR/build-webrtc-bazel.sh "$$BUILD_DIR" $$BUILD_ARCH
    """ + "\n".join([
        "cp -f $$BUILD_DIR/src/out/$$OUT_DIR/obj/sdk/libframework_objc_static.a $(location {lib})".format(lib=lib) for lib in webrtc_libs
    ]),
    outs = webrtc_libs,
    visibility = ["//visibility:public",]
)

cc_library(
    name = "webrtc_lib",
    srcs = [":" + x for x in webrtc_libs],
    visibility = ["//visibility:public"],
)
