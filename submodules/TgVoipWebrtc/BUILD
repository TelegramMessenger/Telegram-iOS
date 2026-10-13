load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_cc//cc:objc_library.bzl", "objc_library")

load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")

config_setting(
    name = "debug_build",
    values = {
        "compilation_mode": "dbg",
    },
)

config_setting(
    name = "is_macos",
    constraint_values = ["@platforms//os:macos"],
)

optimization_flags = select({
    ":debug_build": [
    ],
    "//conditions:default": ["-DNDEBUG"],
})

_WASM_CORE_COMMON_SRCS = [
    "tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp",
    "tgcalls/tgcalls/v2wasm/ReferenceCallCore.h",
    "tgcalls/tgcalls/v2wasm/CallCoreABI.h",
    "tgcalls/tgcalls/v2wasm/CoreFactory.h",
    "tgcalls/tgcalls/v2wasm/SignalingFraming.cpp",
    "tgcalls/tgcalls/v2wasm/SignalingFraming.h",
    "tgcalls/tgcalls/v2wasm/CoreGzip.cpp",
    "tgcalls/tgcalls/v2wasm/CoreGzip.h",
    "tgcalls/tgcalls/v2wasm/CoreBase64.h",
    "tgcalls/tgcalls/v2wasm/wasm_module_entry.cpp",
    "tgcalls/tgcalls/third-party/json11.cpp",
    "tgcalls/tgcalls/third-party/json11.hpp",
]

# {extra_srcs} = per-module factory (+ variant) TUs, one absolute-ish path
# per line ending in " \\".
# NOTE: --strip-all removes the wasm name section (~86% of the module: 996 KB
# -> 172 KB, measured 2026-07-03). Cost: WAMR trap backtraces show function
# indices instead of names. Drop the flag locally when debugging a module
# trap.
# NOTE: -Oz -flto (default wasm-ld LTO level; --lto-O3 measured 8 KB BIGGER)
# takes the reference module to 129 KB. The size-over-speed trade is free
# here: the module is interpreter-run control-plane code (~10 Hz, KB-scale
# payloads).
_WASM_CORE_CMD = """
set -e
SDK_CLANG="$(execpath {sdk}//:bin/clang++)"
SDK_DIR="$$(cd "$$(dirname "$$SDK_CLANG")/.." && pwd)"
"$$SDK_CLANG" --target=wasm32-wasip1 --sysroot="$$SDK_DIR/share/wasi-sysroot" \\
    -std=c++17 -Oz -flto -fno-exceptions -fno-rtti \\
    -mexec-model=reactor -Wl,--no-entry,--strip-all \\
    -Isubmodules/TgVoipWebrtc/tgcalls/tgcalls \\
    submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp \\
    submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/SignalingFraming.cpp \\
    submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CoreGzip.cpp \\
    submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/wasm_module_entry.cpp \\
    submodules/TgVoipWebrtc/tgcalls/tgcalls/third-party/json11.cpp \\
{extra_srcs}    -o $@
"""

_WASM_REFERENCE_EXTRA_SRCS = """    submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/reference_core_factory.cpp \\
"""

genrule(
    name = "reference_core_wasm",
    srcs = _WASM_CORE_COMMON_SRCS + [
        "tgcalls/tgcalls/v2wasm/reference_core_factory.cpp",
    ] + select({
        "@platforms//os:linux": ["@wasi_sdk_linux//:all_files"],
        "//conditions:default": ["@wasi_sdk_macos//:all_files"],
    }),
    outs = ["reference-core-abi1.wasm"],
    cmd_bash = select({
        "@platforms//os:linux": _WASM_CORE_CMD.format(sdk = "@wasi_sdk_linux", extra_srcs = _WASM_REFERENCE_EXTRA_SRCS),
        "//conditions:default": _WASM_CORE_CMD.format(sdk = "@wasi_sdk_macos", extra_srcs = _WASM_REFERENCE_EXTRA_SRCS),
    }),
    tools = select({
        "@platforms//os:linux": ["@wasi_sdk_linux//:bin/clang++"],
        "//conditions:default": ["@wasi_sdk_macos//:bin/clang++"],
    }),
    visibility = ["//visibility:public"],
)

_WASM_VARIANT_EXTRA_SRCS = """    submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/VariantCallCore.cpp \\
    submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/variant_core_factory.cpp \\
"""

genrule(
    name = "variant_core_wasm",
    srcs = _WASM_CORE_COMMON_SRCS + [
        "tgcalls/tgcalls/v2wasm/VariantCallCore.cpp",
        "tgcalls/tgcalls/v2wasm/VariantCallCore.h",
        "tgcalls/tgcalls/v2wasm/variant_core_factory.cpp",
    ] + select({
        "@platforms//os:linux": ["@wasi_sdk_linux//:all_files"],
        "//conditions:default": ["@wasi_sdk_macos//:all_files"],
    }),
    outs = ["variant-core-abi1.wasm"],
    cmd_bash = select({
        "@platforms//os:linux": _WASM_CORE_CMD.format(sdk = "@wasi_sdk_linux", extra_srcs = _WASM_VARIANT_EXTRA_SRCS),
        "//conditions:default": _WASM_CORE_CMD.format(sdk = "@wasi_sdk_macos", extra_srcs = _WASM_VARIANT_EXTRA_SRCS),
    }),
    tools = select({
        "@platforms//os:linux": ["@wasi_sdk_linux//:bin/clang++"],
        "//conditions:default": ["@wasi_sdk_macos//:bin/clang++"],
    }),
    visibility = ["//visibility:public"],
)

# Converts the reference module into a C++ byte array so it ships inside the
# binary. Production builds have no filesystem loader (see
# TGCALLS_ALLOW_EXTERNAL_WASM_CORE), so this is the only module they can run.
genrule(
    name = "reference_core_embedded_src",
    srcs = [
        ":reference_core_wasm",
        "tools/wasm_to_source.py",
    ],
    outs = ["ReferenceCoreEmbedded.cpp"],
    cmd = "python3 $(location tools/wasm_to_source.py) $(location :reference_core_wasm) $@",
    visibility = ["//visibility:public"],
)

sources = glob([
    "Sources/**/*.m",
    "Sources/**/*.mm",
    "Sources/**/*.h",
    "tgcalls/tgcalls/**/*.h",
    "tgcalls/tgcalls/**/*.hpp",
    "tgcalls/tgcalls/**/*.cpp",
    "tgcalls/tgcalls/**/*.mm",
    "tgcalls/tgcalls/**/*.m",
], allow_empty=True, exclude = [
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
    "tgcalls/tgcalls/platform/darwin/GLVideoView.*",
    "tgcalls/tgcalls/platform/darwin/GLVideoViewMac.*",
    "tgcalls/tgcalls/platform/darwin/ScreenCapturer.*",
    "tgcalls/tgcalls/platform/darwin/DesktopSharingCapturer.*",
    "tgcalls/tgcalls/platform/darwin/DesktopCaptureSourceViewMac.*",
    "tgcalls/tgcalls/platform/darwin/DesktopCaptureSourceView.*",
    "tgcalls/tgcalls/platform/darwin/TGCMIODevice.*",
    "tgcalls/tgcalls/platform/darwin/TGCMIOCapturer.*",
    "tgcalls/tgcalls/platform/darwin/VideoCMIOCapture.*",
    "tgcalls/tgcalls/desktop_capturer/**",
])

sources = glob([
    "Sources/**/*.m",
    "Sources/**/*.mm",
    "Sources/**/*.h",
    "tgcalls/tgcalls/**/*.h",
    "tgcalls/tgcalls/**/*.hpp",
    "tgcalls/tgcalls/platform/darwin/**/*.cpp",
    "tgcalls/tgcalls/platform/darwin/**/*.m",
    "tgcalls/tgcalls/platform/darwin/**/*.mm",
    "tgcalls/tgcalls/platform/darwin/**/*.cc",
    "tgcalls/tgcalls/platform/darwin/**/*.c",
    "tgcalls/tgcalls/third-party/**/*.cpp",
    "tgcalls/tgcalls/utils/**/*.cpp",
], allow_empty=True, exclude = [
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
    "tgcalls/tgcalls/platform/darwin/GLVideoView.*",
    "tgcalls/tgcalls/platform/darwin/GLVideoViewMac.*",
    "tgcalls/tgcalls/platform/darwin/ScreenCapturer.*",
    "tgcalls/tgcalls/platform/darwin/DesktopSharingCapturer.*",
    "tgcalls/tgcalls/platform/darwin/DesktopCaptureSourceViewMac.*",
    "tgcalls/tgcalls/platform/darwin/DesktopCaptureSourceView.*",
    "tgcalls/tgcalls/platform/darwin/TGCMIODevice.*",
    "tgcalls/tgcalls/platform/darwin/TGCMIOCapturer.*",
    "tgcalls/tgcalls/platform/darwin/VideoCMIOCapture.*",
    "tgcalls/tgcalls/desktop_capturer/**",
]) + [
    "tgcalls/tgcalls/Manager.cpp",
    "tgcalls/tgcalls/MediaManager.cpp",
    "tgcalls/tgcalls/AudioDeviceHelper.cpp",
    "tgcalls/tgcalls/ChannelManager.cpp",
    "tgcalls/tgcalls/CodecSelectHelper.cpp",
    "tgcalls/tgcalls/CryptoHelper.cpp",
    "tgcalls/tgcalls/EncryptedConnection.cpp",
    "tgcalls/tgcalls/FakeAudioDeviceModule.cpp",
    "tgcalls/tgcalls/FakeVideoTrackSource.cpp",
    "tgcalls/tgcalls/FieldTrialsConfig.cpp",
    "tgcalls/tgcalls/Instance.cpp",
    "tgcalls/tgcalls/InstanceImpl.cpp",
    "tgcalls/tgcalls/LogSinkImpl.cpp",
    "tgcalls/tgcalls/Message.cpp",
    "tgcalls/tgcalls/NetworkManager.cpp",
    "tgcalls/tgcalls/SctpDataChannelProviderInterfaceImpl.cpp",
    "tgcalls/tgcalls/StaticThreads.cpp",
    "tgcalls/tgcalls/ThreadLocalObject.cpp",
    "tgcalls/tgcalls/TurnCustomizerImpl.cpp",
    "tgcalls/tgcalls/VideoCaptureInterface.cpp",
    "tgcalls/tgcalls/VideoCaptureInterfaceImpl.cpp",

    "tgcalls/tgcalls/group/AudioStreamingPart.cpp",
    "tgcalls/tgcalls/group/AudioStreamingPartInternal.cpp",
    "tgcalls/tgcalls/group/AudioStreamingPartPersistentDecoder.cpp",
    "tgcalls/tgcalls/group/AVIOContextImpl.cpp",
    "tgcalls/tgcalls/group/GroupAudioCapturePostProcessor.cpp",
    "tgcalls/tgcalls/group/GroupFrameTransformer.cpp",
    "tgcalls/tgcalls/group/GroupInstanceCustomImpl.cpp",
    "tgcalls/tgcalls/group/GroupInstanceReferenceImpl.cpp",
    "tgcalls/tgcalls/group/GroupJoinPayloadInternal.cpp",
    "tgcalls/tgcalls/group/GroupNetworkManager.cpp",
    "tgcalls/tgcalls/group/StreamingMediaContext.cpp",
    "tgcalls/tgcalls/group/StreamingAudioRenderer.cpp",
    "tgcalls/tgcalls/group/VideoStreamingPart.cpp",

    "tgcalls/tgcalls/v2/ContentNegotiation.cpp",
    "tgcalls/tgcalls/v2/DirectNetworkingImpl.cpp",
    "tgcalls/tgcalls/v2/ExternalSignalingConnection.cpp",
    "tgcalls/tgcalls/v2/InstanceV2Impl.cpp",
    "tgcalls/tgcalls/v2/InstanceV2CompatImpl.cpp",
    "tgcalls/tgcalls/v2/InstanceV2ReferenceImpl.cpp",
    "tgcalls/tgcalls/v2/MtProtoDtlsTransport.cpp",
    "tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp",
    "tgcalls/tgcalls/v2wasm/SignalingFraming.cpp",
    "tgcalls/tgcalls/v2wasm/CoreGzip.cpp",
    "tgcalls/tgcalls/v2wasm/CallCoreHost.cpp",
    "tgcalls/tgcalls/v2wasm/HostCompressionService.cpp",
    "tgcalls/tgcalls/v2wasm/InstanceV2PumpImpl.cpp",
    "tgcalls/tgcalls/v2wasm/NativeCoreBackend.cpp",
    "tgcalls/tgcalls/v2wasm/WamrCoreBackend.cpp",
    ":reference_core_embedded_src",
    "tgcalls/tgcalls/v2/NativeNetworkingImpl.cpp",
    "tgcalls/tgcalls/v2/RawTcpSocket.cpp",
    "tgcalls/tgcalls/v2/ReflectorPort.cpp",
    "tgcalls/tgcalls/v2/ReflectorRelayPortFactory.cpp",
    "tgcalls/tgcalls/v2/Signaling.cpp",
    "tgcalls/tgcalls/v2/SignalingConnection.cpp",
    "tgcalls/tgcalls/v2/SignalingEncryption.cpp",
    "tgcalls/tgcalls/v2/SignalingSctpConnection.cpp",
    "tgcalls/tgcalls/v2/CustomDcSctpSocket.cpp",
    "tgcalls/tgcalls/v2/SignalingTranslator.cpp",
]

objc_library(
    name = "TgVoipWebrtc",
    enable_modules = True,
    module_name = "TgVoipWebrtc",
    srcs = sources,
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    copts = [
        "-I{}/tgcalls/tgcalls".format(package_name()),
        "-Ithird-party/webrtc/webrtc",
        "-Ithird-party/webrtc/dependencies",
        "-Ithird-party/webrtc/webrtc/sdk/objc",
        "-Ithird-party/webrtc/webrtc/sdk/objc/base",
        "-Ithird-party/webrtc/webrtc/sdk/objc/components/renderer/metal",
        "-Ithird-party/webrtc/webrtc/sdk/objc/components/renderer/opengl",
        "-Ithird-party/webrtc/webrtc/sdk/objc/components/video_codec",
        "-Ithird-party/libyuv",
        "-Ithird-party/webrtc/webrtc/sdk/objc/api/video_codec",
        "-Ithird-party/webrtc/absl",
        "-DWEBRTC_IOS",
        "-DWEBRTC_MAC",
        "-DWEBRTC_POSIX",
        "-DRTC_ENABLE_VP9",
        "-DTGVOIP_NAMESPACE=tgvoip_webrtc",
        "-std=c++17",
        "-w",
        #"-Werror",
    ] + optimization_flags,
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//third-party/webrtc",
        "//third-party/webrtc:webrtc_objc",
        "//submodules/MtProtoKit:MtProtoKit",
        "//third-party/boringssl:crypto",
        "//third-party/boringssl:ssl",
        "//third-party/ogg:ogg",
        "//third-party/opusfile:opusfile",
        "//submodules/ffmpeg:ffmpeg",
        "//third-party/rnnoise:rnnoise",
        "//third-party/libyuv",
        "//third-party/td:TdBinding",
        "//third-party/wamr:wamr",
    ],
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
    sdk_dylibs = [
        "libz",
    ],
    visibility = [
        "//visibility:public",
    ],
)

cc_test(
    name = "mtproto_dtls_transport_test",
    srcs = ["tgcalls/tgcalls/v2/MtProtoDtlsTransportTest.cpp"],
    copts = [
        "-I{}/tgcalls/tgcalls".format("submodules/TgVoipWebrtc"),
        "-Ithird-party/webrtc/webrtc",
        "-Ithird-party/webrtc/dependencies",
        "-Ithird-party/webrtc/absl",
        "-Ithird-party/libyuv",
        "-DRTC_ENABLE_VP9",
        "-DNDEBUG",
        "-std=c++17",
        "-w",
    ] + select({
        "@platforms//os:linux": ["-DWEBRTC_LINUX", "-DWEBRTC_POSIX"],
        "//conditions:default": ["-DWEBRTC_MAC", "-DWEBRTC_POSIX"],
    }),
    linkopts = select({
        "@platforms//os:linux": ["-lpthread", "-lm", "-ldl"],
        "//conditions:default": ["-framework", "CoreFoundation", "-framework", "Security"],
    }),
    deps = [":tgcalls_core"],
)

cc_test(
    name = "streaming_audio_renderer_test",
    srcs = ["tgcalls/tgcalls/group/StreamingAudioRendererTest.cpp"],
    copts = [
        "-I{}/tgcalls/tgcalls".format("submodules/TgVoipWebrtc"),
        "-Ithird-party/webrtc/webrtc",
        "-Ithird-party/webrtc/dependencies",
        "-Ithird-party/webrtc/absl",
        "-Ithird-party/libyuv",
        "-DRTC_ENABLE_VP9",
        "-DNDEBUG",
        "-std=c++17",
        "-w",
    ] + select({
        "@platforms//os:linux": ["-DWEBRTC_LINUX", "-DWEBRTC_POSIX"],
        "//conditions:default": ["-DWEBRTC_MAC", "-DWEBRTC_POSIX"],
    }),
    linkopts = select({
        "@platforms//os:linux": ["-lpthread", "-lm", "-ldl"],
        "//conditions:default": ["-framework", "CoreFoundation", "-framework", "Security"],
    }),
    deps = [":tgcalls_core"],
)

cc_test(
    name = "group_frame_transformer_test",
    srcs = ["tgcalls/tgcalls/group/GroupFrameTransformerTest.cpp"],
    copts = [
        "-I{}/tgcalls/tgcalls".format("submodules/TgVoipWebrtc"),
        "-Ithird-party/webrtc/webrtc",
        "-Ithird-party/webrtc/dependencies",
        "-Ithird-party/webrtc/absl",
        "-Ithird-party/libyuv",
        "-DRTC_ENABLE_VP9",
        "-DNDEBUG",
        "-std=c++17",
        "-w",
    ] + select({
        "@platforms//os:linux": ["-DWEBRTC_LINUX", "-DWEBRTC_POSIX"],
        "//conditions:default": ["-DWEBRTC_MAC", "-DWEBRTC_POSIX"],
    }),
    linkopts = select({
        "@platforms//os:linux": ["-lpthread", "-lm", "-ldl"],
        "//conditions:default": ["-framework", "CoreFoundation", "-framework", "Security"],
    }),
    deps = [":tgcalls_core"],
)

# Pure C++ core library for non-iOS targets (e.g. CLI tools).
# Uses FakeInterface instead of darwin platform files.
cc_library(
    name = "tgcalls_core",
    srcs = glob([
        "tgcalls/tgcalls/**/*.h",
        "tgcalls/tgcalls/**/*.hpp",
        "tgcalls/tgcalls/platform/fake/**/*.cpp",
        "tgcalls/tgcalls/third-party/**/*.cpp",
        "tgcalls/tgcalls/utils/**/*.cpp",
    ], allow_empty=True, exclude = [
        "tgcalls/tgcalls/legacy/**",
        "tgcalls/tgcalls/platform/tdesktop/**",
        "tgcalls/tgcalls/platform/android/**",
        "tgcalls/tgcalls/platform/windows/**",
        "tgcalls/tgcalls/platform/uwp/**",
        "tgcalls/tgcalls/platform/darwin/**",
        "tgcalls/tgcalls/desktop_capturer/**",
    ]) + [
        "tgcalls/tgcalls/Manager.cpp",
        "tgcalls/tgcalls/MediaManager.cpp",
        "tgcalls/tgcalls/AudioDeviceHelper.cpp",
        "tgcalls/tgcalls/ChannelManager.cpp",
        "tgcalls/tgcalls/CodecSelectHelper.cpp",
        "tgcalls/tgcalls/CryptoHelper.cpp",
        "tgcalls/tgcalls/EncryptedConnection.cpp",
        "tgcalls/tgcalls/FakeAudioDeviceModule.cpp",
        "tgcalls/tgcalls/FakeVideoTrackSource.cpp",
        "tgcalls/tgcalls/FieldTrialsConfig.cpp",
        "tgcalls/tgcalls/Instance.cpp",
        "tgcalls/tgcalls/InstanceImpl.cpp",
        "tgcalls/tgcalls/LogSinkImpl.cpp",
        "tgcalls/tgcalls/Message.cpp",
        "tgcalls/tgcalls/NetworkManager.cpp",
        "tgcalls/tgcalls/SctpDataChannelProviderInterfaceImpl.cpp",
        "tgcalls/tgcalls/StaticThreads.cpp",
        "tgcalls/tgcalls/ThreadLocalObject.cpp",
        "tgcalls/tgcalls/TurnCustomizerImpl.cpp",
        "tgcalls/tgcalls/VideoCaptureInterface.cpp",
        "tgcalls/tgcalls/VideoCaptureInterfaceImpl.cpp",

        "tgcalls/tgcalls/group/AudioStreamingPart.cpp",
        "tgcalls/tgcalls/group/AudioStreamingPartInternal.cpp",
        "tgcalls/tgcalls/group/AudioStreamingPartPersistentDecoder.cpp",
        "tgcalls/tgcalls/group/AVIOContextImpl.cpp",
        "tgcalls/tgcalls/group/GroupAudioCapturePostProcessor.cpp",
        "tgcalls/tgcalls/group/GroupFrameTransformer.cpp",
        "tgcalls/tgcalls/group/GroupInstanceCustomImpl.cpp",
        "tgcalls/tgcalls/group/GroupInstanceReferenceImpl.cpp",
        "tgcalls/tgcalls/group/GroupJoinPayloadInternal.cpp",
        "tgcalls/tgcalls/group/GroupNetworkManager.cpp",
        "tgcalls/tgcalls/group/StreamingMediaContext.cpp",
        "tgcalls/tgcalls/group/StreamingAudioRenderer.cpp",
        "tgcalls/tgcalls/group/VideoStreamingPart.cpp",

        "tgcalls/tgcalls/v2/ContentNegotiation.cpp",
        "tgcalls/tgcalls/v2/DirectNetworkingImpl.cpp",
        "tgcalls/tgcalls/v2/ExternalSignalingConnection.cpp",
        "tgcalls/tgcalls/v2/InstanceV2Impl.cpp",
        "tgcalls/tgcalls/v2/InstanceV2CompatImpl.cpp",
        "tgcalls/tgcalls/v2/InstanceV2ReferenceImpl.cpp",
        "tgcalls/tgcalls/v2/MtProtoDtlsTransport.cpp",
        "tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp",
        "tgcalls/tgcalls/v2wasm/SignalingFraming.cpp",
        "tgcalls/tgcalls/v2wasm/CoreGzip.cpp",
        "tgcalls/tgcalls/v2wasm/CallCoreHost.cpp",
        "tgcalls/tgcalls/v2wasm/HostCompressionService.cpp",
        "tgcalls/tgcalls/v2wasm/InstanceV2PumpImpl.cpp",
        "tgcalls/tgcalls/v2wasm/NativeCoreBackend.cpp",
        "tgcalls/tgcalls/v2wasm/WamrCoreBackend.cpp",
        ":reference_core_embedded_src",
        "tgcalls/tgcalls/v2/NativeNetworkingImpl.cpp",
        "tgcalls/tgcalls/v2/RawTcpSocket.cpp",
        "tgcalls/tgcalls/v2/ReflectorPort.cpp",
        "tgcalls/tgcalls/v2/ReflectorRelayPortFactory.cpp",
        "tgcalls/tgcalls/v2/Signaling.cpp",
        "tgcalls/tgcalls/v2/SignalingConnection.cpp",
        "tgcalls/tgcalls/v2/SignalingEncryption.cpp",
        "tgcalls/tgcalls/v2/SignalingSctpConnection.cpp",
        "tgcalls/tgcalls/v2/SignalingTranslator.cpp",
    "tgcalls/tgcalls/v2/CustomDcSctpSocket.cpp",
    ],
    copts = [
        "-I{}/tgcalls/tgcalls".format(package_name()),
        "-Ithird-party/webrtc/webrtc",
        "-Ithird-party/webrtc/dependencies",
        "-Ithird-party/webrtc/absl",
        "-Ithird-party/libyuv",
        "-DRTC_ENABLE_VP9",
        "-DTGVOIP_NAMESPACE=tgvoip_webrtc",
        # CLI/dev only: enables --wasm-core PATH. NEVER add this to the
        # objc_library — the key it unlocks comes from the server, so in a
        # shipped build it would be a remote-code-execution surface. See the
        # security note in v2wasm/CallCoreHost.cpp.
        "-DTGCALLS_ALLOW_EXTERNAL_WASM_CORE=1",
        "-std=c++17",
        "-w",
    ] + select({
        "@platforms//os:linux": ["-DWEBRTC_LINUX", "-DWEBRTC_POSIX"],
        "//conditions:default": ["-DWEBRTC_MAC", "-DWEBRTC_POSIX"],
    }) + optimization_flags,
    deps = [
        "//third-party/webrtc",
        "//third-party/boringssl:crypto",
        "//third-party/boringssl:ssl",
        "//third-party/ogg:ogg",
        "//third-party/opusfile:opusfile",
        "//submodules/ffmpeg:ffmpeg",
        "//third-party/rnnoise:rnnoise",
        "//third-party/libyuv",
        "//third-party/wamr:wamr",
    ] + select({
        ":is_macos": ["//third-party/webrtc:webrtc_platform_helpers"],
        "//conditions:default": [],
    }),
    linkopts = ["-lz"],
    visibility = [
        "//visibility:public",
    ],
)
