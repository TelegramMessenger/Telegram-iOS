load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SelectablePeerNode",
    module_name = "SelectablePeerNode",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/PeerOnlineMarkerNode:PeerOnlineMarkerNode",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/ContextUI:ContextUI",
        "//submodules/LocalizedPeerData:LocalizedPeerData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/CheckNode:CheckNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
