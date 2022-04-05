load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LegacyMediaPickerUI",
    module_name = "LegacyMediaPickerUI",
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
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/LegacyUI:LegacyUI",
        "//submodules/MimeTypes:MimeTypes",
        "//submodules/LocalMediaResources:LocalMediaResources",
        "//submodules/SearchPeerMembers:SearchPeerMembers",
        "//submodules/SaveToCameraRoll:SaveToCameraRoll",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/StickerResources:StickerResources",
        "//submodules/TextFormat:TextFormat",
        "//submodules/AttachmentUI:AttachmentUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
