load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MoreHeaderButton",
    module_name = "MoreHeaderButton",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/LottieComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
