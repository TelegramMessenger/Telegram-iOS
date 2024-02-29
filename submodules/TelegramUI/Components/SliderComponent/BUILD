load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SliderComponent",
    module_name = "SliderComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/LegacyComponents",
        "//submodules/ComponentFlow",
    ],
    visibility = [
        "//visibility:public",
    ],
)
