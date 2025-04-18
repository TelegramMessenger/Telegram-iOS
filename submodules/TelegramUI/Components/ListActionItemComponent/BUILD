load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ListActionItemComponent",
    module_name = "ListActionItemComponent",
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
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/SwitchNode",
        "//submodules/CheckNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
