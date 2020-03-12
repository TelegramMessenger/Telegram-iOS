load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "GalleryUI",
    module_name = "GalleryUI",
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
        "//submodules/TextFormat:TextFormat",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramUniversalVideoContent:TelegramUniversalVideoContent",
        "//submodules/WebsiteType:WebsiteType",
        "//submodules/ScreenCaptureDetection:ScreenCaptureDetection",
        "//submodules/OpenInExternalAppUI:OpenInExternalAppUI",
        "//submodules/ShareController:ShareController",
        "//submodules/SwipeToDismissGesture:SwipeToDismissGesture",
        "//submodules/CheckNode:CheckNode",
        "//submodules/AppBundle:AppBundle",
        "//submodules/StickerPackPreviewUI:StickerPackPreviewUI",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
