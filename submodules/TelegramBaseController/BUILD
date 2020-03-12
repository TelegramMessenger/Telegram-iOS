load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TelegramBaseController",
    module_name = "TelegramBaseController",
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
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/LiveLocationTimerNode:LiveLocationTimerNode",
        "//submodules/AccountContext:AccountContext",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/Markdown:Markdown",
    ],
    visibility = [
        "//visibility:public",
    ],
)
