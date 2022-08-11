load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "UniversalMediaPlayer",
    module_name = "UniversalMediaPlayer",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Postbox:Postbox",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramAudio:TelegramAudio",
        "//submodules/FFMpegBinding:FFMpegBinding",
        "//submodules/RingBuffer:RingBuffer",
        "//submodules/YuvConversion:YuvConversion",
        "//submodules/Utils/RangeSet:RangeSet",
    ],
    visibility = [
        "//visibility:public",
    ],
)
