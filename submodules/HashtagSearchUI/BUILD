load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "HashtagSearchUI",
    module_name = "HashtagSearchUI",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramBaseController:TelegramBaseController",
        "//submodules/ChatListUI:ChatListUI",
        "//submodules/SegmentedControlNode:SegmentedControlNode",
        "//submodules/ListMessageItem:ListMessageItem",
        "//submodules/ChatListSearchItemHeader:ChatListSearchItemHeader",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramUI/Components/AnimationCache:AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer:MultiAnimationRenderer",
        "//submodules/ComponentFlow",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramUI/Components/Stories/StorySetIndicatorComponent",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoVisualMediaPaneNode",
        "//submodules/TelegramUI/Components/AnimatedTextComponent",
        "//submodules/Components/BlurredBackgroundComponent",
        "//submodules/UIKitRuntimeUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
