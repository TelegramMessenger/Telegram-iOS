load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ListSwitchItemComponent",
    module_name = "ListSwitchItemComponent",
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
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/TelegramUI/Components/SwitchComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
