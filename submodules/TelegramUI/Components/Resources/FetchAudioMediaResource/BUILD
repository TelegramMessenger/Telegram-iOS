load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FetchAudioMediaResource",
    module_name = "FetchAudioMediaResource",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Postbox",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/LegacyComponents",
        "//submodules/FFMpegBinding",
        "//submodules/LocalMediaResources",
    ],
    visibility = [
        "//visibility:public",
    ],
)
