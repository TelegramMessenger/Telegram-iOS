load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "BatchVideoRendering",
    module_name = "BatchVideoRendering",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/Display",
        "//submodules/AccountContext",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
