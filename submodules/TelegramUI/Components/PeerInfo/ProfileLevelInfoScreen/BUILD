load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ProfileLevelInfoScreen",
    module_name = "ProfileLevelInfoScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/PresentationDataUtils",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/AppBundle",
        "//submodules/Markdown",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/PremiumUI",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/TelegramUI/Components/Utils/RoundedRectWithTailPath",
        "//submodules/Components/HierarchyTrackingLayer",
        "//submodules/TelegramUI/Components/AnimatedTextComponent",
        "//submodules/TelegramUI/Components/PeerInfo/ProfileLevelRatingBarComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
