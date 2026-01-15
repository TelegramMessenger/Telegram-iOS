load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "HorizontalTabsComponent",
    module_name = "HorizontalTabsComponent",
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
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/AsyncDisplayKit",
        "//submodules/AnimationUI",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/Components/MultilineTextWithEntitiesComponent",
        "//submodules/TelegramUI/Components/LiquidLens",
        "//submodules/TelegramUI/Components/TextBadgeComponent",
        "//submodules/TelegramUI/Components/HeaderPanelContainerComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
