load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatInstantVideoMessageDurationNode",
    module_name = "ChatInstantVideoMessageDurationNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Display",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/AnimatedCountLabelNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
