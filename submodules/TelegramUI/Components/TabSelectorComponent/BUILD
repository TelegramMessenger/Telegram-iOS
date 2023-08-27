load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TabSelectorComponent",
    module_name = "TabSelectorComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
