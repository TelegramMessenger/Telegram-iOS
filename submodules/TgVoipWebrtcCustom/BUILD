
objc_library(
    name = "TgVoipWebrtcCustom",
    enable_modules = True,
    module_name = "TgVoipWebrtcCustom",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.mm",
        "Sources/**/*.h",
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
        "-std=c++14",
    ],
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//third-party/webrtc:webrtc_lib",
        "//submodules/MtProtoKit:MtProtoKit",
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
