load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AlertMultilineInputFieldComponent",
    module_name = "AlertMultilineInputFieldComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/TextFormat",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramUI/Components/AlertComponent",
        "//submodules/TelegramUI/Components/TextFieldComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
