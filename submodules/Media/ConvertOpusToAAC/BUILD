load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ConvertOpusToAAC",
    module_name = "ConvertOpusToAAC",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/FFMpegBinding:FFMpegBinding",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
    ],
    visibility = [
        "//visibility:public",
    ],
)
