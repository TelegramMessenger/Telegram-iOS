load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "StoryFooterPanelComponent",
    module_name = "StoryFooterPanelComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/AppBundle",
        "//submodules/Components/BundleIconComponent",
        "//submodules/AnimatedAvatarSetNode",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/TelegramUI/Components/MoreHeaderButton",
        "//submodules/SemanticStatusNode",
        "//submodules/AnimatedCountLabelNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
