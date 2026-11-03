load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

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
        "//submodules/TextFormat:TextFormat",
        "//submodules/ManagedFile",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "UniversalMediaPlayerTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":UniversalMediaPlayer",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramAudio:TelegramAudio",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    ],
)

ios_test_runner(
    name = "UniversalMediaPlayerTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "UniversalMediaPlayerTests",
    minimum_os_version = "15.0",
    runner = ":UniversalMediaPlayerTestRunner",
    deps = [
        ":UniversalMediaPlayerTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
