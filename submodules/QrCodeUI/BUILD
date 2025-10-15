load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "QrCodeUI",
    module_name = "QrCodeUI",
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
        "//submodules/AppBundle:AppBundle",
        "//submodules/SolidRoundedButtonNode:SolidRoundedButtonNode",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/GlassButtonNode:GlassButtonNode",
        "//submodules/TextFormat:TextFormat",
        "//submodules/Markdown:Markdown",
        "//submodules/UndoUI:UndoUI",
        "//submodules/Camera:Camera",
        "//submodules/LegacyUI:LegacyUI",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/LegacyMediaPickerUI:LegacyMediaPickerUI",
        "//submodules/ImageContentAnalysis:ImageContentAnalysis",
    ],
    visibility = [
        "//visibility:public",
    ],
)
