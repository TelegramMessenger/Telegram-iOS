
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
        "Impl/*.h",
        "Impl/*.cpp",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    copts = [
        "-I{}/Impl".format(package_name()),
        "-Ithird-party/webrtc/webrtc-ios/src",
        "-Ithird-party/webrtc/webrtc-ios/src/third_party/abseil-cpp",
        "-DWEBRTC_IOS",
        "-DWEBRTC_MAC",
        "-DWEBRTC_POSIX",
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
