load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ShareController",
    module_name = "ShareController",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SaveToCameraRoll:SaveToCameraRoll",
        "//submodules/StickerResources:StickerResources",
        "//submodules/UrlEscaping:UrlEscaping",
        "//submodules/LocalizedPeerData:LocalizedPeerData",
        "//submodules/ActionSheetPeerItem:ActionSheetPeerItem",
        "//submodules/ChatListSearchRecentPeersNode:ChatListSearchRecentPeersNode",
        "//submodules/PeerPresenceStatusManager:PeerPresenceStatusManager",
        "//submodules/SelectablePeerNode:SelectablePeerNode",
        "//submodules/RadialStatusNode:RadialStatusNode",
        "//submodules/ActivityIndicator:ActivityIndicator",
        "//submodules/AppBundle:AppBundle",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/TelegramIntents:TelegramIntents",
        "//submodules/AccountContext:AccountContext",
        "//submodules/SegmentedControlNode:SegmentedControlNode",
        "//submodules/WallpaperBackgroundNode:WallpaperBackgroundNode",
        "//submodules/ShimmerEffect:ShimmerEffect",
        "//submodules/ContextUI:ContextUI",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/TelegramUniversalVideoContent:TelegramUniversalVideoContent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
