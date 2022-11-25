load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "UndoUI",
    module_name = "UndoUI",
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
        "//submodules/TextFormat:TextFormat",
        "//submodules/Markdown:Markdown",
        "//submodules/RadialStatusNode:RadialStatusNode",
        "//submodules/AnimationUI:AnimationUI",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/AppBundle:AppBundle",
        "//submodules/StickerResources:StickerResources",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/SlotMachineAnimationNode:SlotMachineAnimationNode",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/AnimatedAvatarSetNode:AnimatedAvatarSetNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
