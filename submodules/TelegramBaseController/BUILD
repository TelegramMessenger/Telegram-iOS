load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TelegramBaseController",
    module_name = "TelegramBaseController",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
    	"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/LiveLocationTimerNode:LiveLocationTimerNode",
        "//submodules/AccountContext:AccountContext",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/Markdown:Markdown",
        "//submodules/TelegramCallsUI:TelegramCallsUI",
        "//submodules/ManagedAnimationNode:ManagedAnimationNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
