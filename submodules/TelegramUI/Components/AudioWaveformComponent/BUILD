load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AudioWaveformComponent",
    module_name = "AudioWaveformComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/AppBundle:AppBundle",
        "//submodules/Display:Display",
        "//submodules/ShimmerEffect:ShimmerEffect",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
