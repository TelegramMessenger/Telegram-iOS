load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "HorizontalPeerItem",
    module_name = "HorizontalPeerItem",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
	    "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SyncCore:SyncCore",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/SelectablePeerNode:SelectablePeerNode",
        "//submodules/PeerOnlineMarkerNode:PeerOnlineMarkerNode",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/ContextUI:ContextUI",
        "//submodules/AccountContext:AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
