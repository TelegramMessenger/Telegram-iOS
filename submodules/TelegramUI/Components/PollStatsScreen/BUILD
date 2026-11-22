load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PollStatsScreen",
    module_name = "PollStatsScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/Components/SheetComponent",
        "//submodules/ItemListUI",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/ListItemComponentAdaptor",
        "//submodules/TelegramUI/Components/GlassBarButtonComponent",
        "//submodules/StatisticsUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
