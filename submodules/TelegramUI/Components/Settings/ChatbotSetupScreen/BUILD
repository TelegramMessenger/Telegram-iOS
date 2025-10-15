load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatbotSetupScreen",
    module_name = "ChatbotSetupScreen",
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
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/PresentationDataUtils",
        "//submodules/Markdown",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/TelegramUI/Components/AnimatedTextComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/BackButtonComponent",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/ListActionItemComponent",
        "//submodules/TelegramUI/Components/ListTextFieldItemComponent",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/AvatarNode",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/TelegramUI/Components/Stories/PeerListItemComponent",
        "//submodules/ShimmerEffect",
    ],
    visibility = [
        "//visibility:public",
    ],
)
