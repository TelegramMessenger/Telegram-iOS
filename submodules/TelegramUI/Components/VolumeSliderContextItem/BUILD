load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "VolumeSliderContextItem",
    module_name = "VolumeSliderContextItem",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/ContextUI:ContextUI",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AnimatedCountLabelNode:AnimatedCountLabelNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
