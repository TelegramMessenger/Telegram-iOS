load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")

config_setting(
    name = "debug_build",
    values = {
        "compilation_mode": "dbg",
    },
)

optimization_flags = select({
    ":debug_build": [
    ],
    "//conditions:default": ["-DNDEBUG"],
})

enable_x264 = False

objc_library(
    name = "TgVoipWebrtc",
    enable_modules = True,
    module_name = "TgVoipWebrtc",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.mm",
        "Sources/**/*.h",
        "tgcalls/tgcalls/**/*.h",
        "tgcalls/tgcalls/**/*.hpp",
        "tgcalls/tgcalls/**/*.cpp",
        "tgcalls/tgcalls/**/*.mm",
        "tgcalls/tgcalls/**/*.m",
    ], exclude = [
        "tgcalls/tgcalls/legacy/**",
        "tgcalls/tgcalls/platform/tdesktop/**",
        "tgcalls/tgcalls/platform/android/**",
        "tgcalls/tgcalls/platform/windows/**",
        "tgcalls/tgcalls/platform/uwp/**",
        "tgcalls/tgcalls/platform/darwin/SQueue*",
        "tgcalls/tgcalls/platform/darwin/macOS/**",
        "tgcalls/tgcalls/platform/darwin/VideoCameraCapturerMac.*",
        "tgcalls/tgcalls/platform/darwin/VideoMetalViewMac.*",
        "tgcalls/tgcalls/platform/darwin/VideoSampleBufferViewMac.*",
        "tgcalls/tgcalls/platform/darwin/GLVideoViewMac.*",
        "tgcalls/tgcalls/platform/darwin/ScreenCapturer.*",
        "tgcalls/tgcalls/platform/darwin/DesktopSharingCapturer.*",
        "tgcalls/tgcalls/platform/darwin/DesktopCaptureSourceViewMac.*",
        "tgcalls/tgcalls/platform/darwin/DesktopCaptureSourceView.*",
        "tgcalls/tgcalls/platform/darwin/TGCMIODevice.*",
        "tgcalls/tgcalls/platform/darwin/TGCMIOCapturer.*",
        "tgcalls/tgcalls/platform/darwin/VideoCMIOCapture.*",
        "tgcalls/tgcalls/desktop_capturer/**",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    copts = [
        "-I{}/tgcalls/tgcalls".format(package_name()),
        "-Ithird-party/webrtc/webrtc",
        "-Ithird-party/webrtc/dependencies",
        "-Ithird-party/webrtc/dependencies/third_party/abseil-cpp",
        "-Ithird-party/webrtc/webrtc/sdk/objc",
        "-Ithird-party/webrtc/webrtc/sdk/objc/base",
        "-Ithird-party/webrtc/webrtc/sdk/objc/components/renderer/metal",
        "-Ithird-party/webrtc/webrtc/sdk/objc/components/renderer/opengl",
        "-Ithird-party/webrtc/webrtc/sdk/objc/components/video_codec",
        "-Ithird-party/libyuv/third_party/libyuv/include",
        "-Ithird-party/libyuv",
        "-Ithird-party/webrtc/webrtc/sdk/objc/api/video_codec",
        "-DWEBRTC_IOS",
        "-DWEBRTC_MAC",
        "-DWEBRTC_POSIX",
        "-DRTC_ENABLE_VP9",
        "-DTGVOIP_NAMESPACE=tgvoip_webrtc",
        "-std=c++14",
    ] + optimization_flags + (["-DTGCALLS_ENABLE_X264"] if enable_x264 else []),
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//third-party/webrtc:webrtc_lib",
        "//submodules/MtProtoKit:MtProtoKit",
        "//third-party/boringssl:crypto",
        "//third-party/boringssl:ssl",
        "//third-party/ogg:ogg",
        "//third-party/opusfile:opusfile",
        "//submodules/ffmpeg:ffmpeg",
        "//third-party/rnnoise:rnnoise",
        "//third-party/libyuv:libyuv",
    ] + (["//third-party/libx264:libx264"] if enable_x264 else []),
    sdk_frameworks = [
        "Foundation",
        "UIKit",
        "AudioToolbox",
        "VideoToolbox",
        "CoreTelephony",
        "CoreMedia",
        "GLKit",
        "AVFoundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)

objc_library(
    name = "TgCallsTestsLib",
    copts = [
        "-I{}/tgcalls/tgcalls".format(package_name()),
        "-Ithird-party/webrtc/webrtc",
        "-Ithird-party/webrtc/dependencies",
        "-Ithird-party/webrtc/dependencies/third_party/abseil-cpp",
        "-Ithird-party/webrtc/webrtc/sdk/objc",
        "-Ithird-party/webrtc/webrtc/sdk/objc/base",
        "-Ithird-party/webrtc/webrtc/sdk/objc/components/renderer/metal",
        "-Ithird-party/webrtc/webrtc/sdk/objc/components/renderer/opengl",
        "-Ithird-party/webrtc/webrtc/sdk/objc/components/video_codec",
        "-Ithird-party/libyuv/third_party/libyuv/include",
        "-Ithird-party/libyuv",
        "-Ithird-party/webrtc/webrtc/sdk/objc/api/video_codec",
        "-DWEBRTC_IOS",
        "-DWEBRTC_MAC",
        "-DWEBRTC_POSIX",
        "-DRTC_ENABLE_VP9",
        "-DTGVOIP_NAMESPACE=tgvoip_webrtc",
        "-std=c++14",
    ],
    srcs = glob([
        "tests/*.m",
        "tests/*.mm",
    ]),
    deps = [
        ":TgVoipWebrtc"
    ],
)

ios_unit_test(
    name = "TgCallsTests",
    minimum_os_version = "9.0",
    deps = [
        ":TgCallsTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
