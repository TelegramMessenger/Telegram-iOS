load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LottieComponentEmojiContent",
    module_name = "LottieComponentEmojiContent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/AccountContext",
        "//submodules/GZip:GZip",
    ],
    visibility = [
        "//visibility:public",
    ],
)
