load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "BadgeComponent",
    module_name = "BadgeComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/RasterizedCompositionComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
