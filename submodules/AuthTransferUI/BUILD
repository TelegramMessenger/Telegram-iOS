load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AuthTransferUI",
    module_name = "AuthTransferUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/QrCode:QrCode",
        "//submodules/Camera:Camera",
        "//submodules/GlassButtonNode:GlassButtonNode",
        "//submodules/AlertUI:AlertUI",
        "//submodules/AppBundle:AppBundle",
        "//submodules/SolidRoundedButtonNode:SolidRoundedButtonNode",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/AnimationUI:AnimationUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/DeviceAccess:DeviceAccess",
        "//submodules/UndoUI:UndoUI",
        "//submodules/TextFormat:TextFormat",
        "//submodules/Markdown:Markdown",
        "//submodules/QrCodeUI:QrCodeUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
