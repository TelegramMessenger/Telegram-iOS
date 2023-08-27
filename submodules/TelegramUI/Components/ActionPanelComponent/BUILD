load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ActionPanelComponent",
    module_name = "ActionPanelComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ComponentFlow",
        "//submodules/AnimatedCountLabelNode",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
