load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "BottomButtonPanelComponent",
    module_name = "BottomButtonPanelComponent",
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
        "//submodules/TelegramPresentationData",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/Components/SolidRoundedButtonComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
