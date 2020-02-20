load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "JoinLinkPreviewUI",
    module_name = "JoinLinkPreviewUI",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SyncCore:SyncCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/AlertUI:AlertUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/ShareController:ShareController",
        "//submodules/SelectablePeerNode:SelectablePeerNode",
        "//submodules/PeerInfoUI:PeerInfoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
