load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ForwardInfoPanelComponent",
    module_name = "ForwardInfoPanelComponent",
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
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramUI/Components/Chat/MessageInlineBlockBackgroundView",
    ],
    visibility = [
        "//visibility:public",
    ],
)
