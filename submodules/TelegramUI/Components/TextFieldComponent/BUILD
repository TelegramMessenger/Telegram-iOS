load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TextFieldComponent",
    module_name = "TextFieldComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TextFormat",
        "//submodules/TelegramPresentationData",
    ],
    visibility = [
        "//visibility:public",
    ],
)
