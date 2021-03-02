
copts_arm = [
    "-DTGVOIP_USE_CUSTOM_CRYPTO",
    "-DWEBRTC_APM_DEBUG_DUMP=0",
    "-DWEBRTC_POSIX",
    "-DTGVOIP_HAVE_TGLOG",
    "-DWEBRTC_NS_FLOAT",
    "-DWEBRTC_IOS",
    "-DWEBRTC_HAS_NEON",
    "-DTGVOIP_NO_DSP",
]

copts_x86 = [
    "-DTGVOIP_USE_CUSTOM_CRYPTO",
    "-DWEBRTC_APM_DEBUG_DUMP=0",
    "-DWEBRTC_POSIX",
    "-DTGVOIP_HAVE_TGLOG",
    "-DTGVOIP_NO_DSP",
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
        "libtgvoip/*.h",
        "libtgvoip/*.hpp",
        "libtgvoip/*.m",
        "libtgvoip/*.mm",
        "libtgvoip/*.cpp",
        "libtgvoip/audio/*.h",
        "libtgvoip/audio/*.cpp",
        "libtgvoip/video/*.h",
        "libtgvoip/video/*.cpp",
        "libtgvoip/os/darwin/*.h",
        "libtgvoip/os/darwin/*.m",
        "libtgvoip/os/darwin/*.mm",
        "libtgvoip/os/darwin/*.cpp",
        "libtgvoip/os/posix/*.h",
        "libtgvoip/os/posix/*.cpp",
    ], exclude = ["libtgvoip/os/darwin/*OSX*"]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    copts = [
        "-I{}/PublicHeaders/TgVoip".format(package_name()),
        "-I{}/libtgvoip".format(package_name()),
        "-I{}/third-party/webrtc/webrtc".format(package_name()),
        "-Isubmodules/Opus/Public/opus",
        "-DTGVOIP_USE_INSTALLED_OPUS",
        "-Drtc=rtc1",
        "-Dwebrtc=webrtc1",
    ] + select({
        "@build_bazel_rules_apple//apple:ios_armv7": copts_arm,
        "@build_bazel_rules_apple//apple:ios_arm64": copts_arm,
        "//build-system:ios_sim_arm64": copts_arm,
        "@build_bazel_rules_apple//apple:ios_x86_64": copts_x86,
    }),
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//submodules/MtProtoKit:MtProtoKit",
        "//third-party/opus:opus",
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
