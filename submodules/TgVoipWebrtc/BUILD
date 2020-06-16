
cc_library(
    name = "webrtc_lib",
    srcs = ["libwebrtc.a"],
)

objc_library(
    name = "TgVoipWebrtc",
    enable_modules = True,
    module_name = "TgVoipWebrtc",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.mm",
        "Sources/**/*.h",
        "Impl/**/*.h",
        "Impl/**/*.cpp",
        "Impl/**/*.mm",
        "Impl/**/*.m",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    copts = [
        "-I{}/Impl".format(package_name()),
        "-Ithird-party/webrtc/webrtc-ios/src",
        "-Ithird-party/webrtc/webrtc-ios/src/third_party/abseil-cpp",
        "-Ithird-party/webrtc/webrtc-ios/src/sdk/objc",
        "-Ithird-party/webrtc/webrtc-ios/src/sdk/objc/base",
        "-Ithird-party/webrtc/webrtc-ios/src/sdk/objc/components/renderer/metal",
        "-DWEBRTC_IOS",
        "-DWEBRTC_MAC",
        "-DWEBRTC_POSIX",
        "-DRTC_ENABLE_VP9",
        "-DTGVOIP_NAMESPACE=tgvoip_webrtc",
        "-std=c++14",
    ],
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//third-party/webrtc:webrtc_lib",
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/Opus:opus",
        "//submodules/openssl:openssl",
    ],
    sdk_frameworks = [
        "Foundation",
        "UIKit",
        "AudioToolbox",
        "VideoToolbox",
        "CoreTelephony",
        "CoreMedia",
        "AVFoundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
