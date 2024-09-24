load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ContentReportScreen",
    module_name = "ContentReportScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/ItemListUI",
        "//submodules/TelegramStringFormatting",
        "//submodules/PresentationDataUtils",
        "//submodules/Components/SheetComponent",
        "//submodules/UndoUI",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/ListActionItemComponent",
        "//submodules/TelegramUI/Components/NavigationStackComponent",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/TelegramUI/Components/ListMultilineTextFieldItemComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
