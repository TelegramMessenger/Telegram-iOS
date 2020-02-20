load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TelegramBaseController",
    module_name = "TelegramBaseController",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
    	"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit#shared",
        "//submodules/Postbox:Postbox#shared",
        "//submodules/TelegramCore:TelegramCore#shared",
        "//submodules/SyncCore:SyncCore#shared",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit#shared",
        "//submodules/Display:Display#shared",
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
