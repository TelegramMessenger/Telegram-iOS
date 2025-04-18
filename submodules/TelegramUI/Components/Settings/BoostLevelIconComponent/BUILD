load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "BoostLevelIconComponent",
    module_name = "BoostLevelIconComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramPresentationData",
    ],
    visibility = [
        "//visibility:public",
    ],
)
