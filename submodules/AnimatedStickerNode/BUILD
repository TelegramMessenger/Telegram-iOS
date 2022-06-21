load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

config_setting(
    name = "debug_build",
    values = {
        "compilation_mode": "dbg",
    },
)

optimization_flags = select({
    ":debug_build": [
        #"-O",
    ],
    "//conditions:default": [],
})

swift_library(
    name = "AnimatedStickerNode",
    module_name = "AnimatedStickerNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ] + optimization_flags,
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/YuvConversion:YuvConversion",
        "//submodules/GZip:GZip",
        "//submodules/rlottie:RLottieBinding",
        "//submodules/MediaResources:MediaResources",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/ManagedFile:ManagedFile",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AnimationCompression:AnimationCompression",
        "//submodules/Components/MetalImageView:MetalImageView",
    ],
    visibility = [
        "//visibility:public",
    ],
)
