load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AdsInfoScreen",
    module_name = "AdsInfoScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/ResizableSheetComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/TelegramStringFormatting",
        "//submodules/PresentationDataUtils",
        "//submodules/ContextUI",
        "//submodules/UndoUI",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/GlassBarButtonComponent",
        "//submodules/TelegramUI/Components/Ads/AdsReportScreen",
        "//submodules/TelegramUI/Components/LottieComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
