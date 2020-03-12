
copts_arm = [
    "-DTGVOIP_USE_CUSTOM_CRYPTO",
    "-DWEBRTC_APM_DEBUG_DUMP=0",
    "-DWEBRTC_POSIX",
    "-DTGVOIP_HAVE_TGLOG",
    "-DWEBRTC_NS_FLOAT",
    "-DWEBRTC_IOS",
    "-DWEBRTC_HAS_NEON",
]

copts_x86 = [
    "-DTGVOIP_USE_CUSTOM_CRYPTO",
    "-DWEBRTC_APM_DEBUG_DUMP=0",
    "-DWEBRTC_POSIX",
    "-DTGVOIP_HAVE_TGLOG",
    "-DWEBRTC_NS_FLOAT",
    "-DWEBRTC_IOS",
]

objc_library(
    name = "TgVoip",
    enable_modules = True,
    module_name = "TgVoip",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.mm",
        "Sources/**/*.h",
        "libtgvoip/*.m",
        "libtgvoip/*.mm",
        "libtgvoip/*.cpp",
        "libtgvoip/audio/*.cpp",
        "libtgvoip/video/*.cpp",
        "libtgvoip/os/darwin/*.m",
        "libtgvoip/os/darwin/*.mm",
        "libtgvoip/os/darwin/*.cpp",
        "libtgvoip/os/posix/*.cpp",
        "libtgvoip/webrtc_dsp/**/*.c",
        "libtgvoip/webrtc_dsp/**/*.cc",
        "libtgvoip/webrtc_dsp/**/*.cpp",
    ], exclude = ["libtgvoip/os/darwin/*OSX*"]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    copts = [
        "-I{}/PublicHeaders/TgVoip".format(package_name()),
        "-I{}/libtgvoip".format(package_name()),
        "-I{}/libtgvoip/webrtc_dsp".format(package_name()),
        "-DTGVOIP_USE_INSTALLED_OPUS",
    ] + select({
        "@build_bazel_rules_apple//apple:ios_armv7": copts_arm,
        "@build_bazel_rules_apple//apple:ios_arm64": copts_arm,
        "@build_bazel_rules_apple//apple:ios_x86_64": copts_x86,
    }),
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/Opus:opus",
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
