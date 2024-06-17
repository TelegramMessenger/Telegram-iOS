load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AudioBlob",
    module_name = "AudioBlob",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/LegacyComponents",
        "//submodules/MetalEngine",
        "//submodules/TelegramUI/Components/Calls/CallScreen",
    ],
    visibility = [
        "//visibility:public",
    ],
)
