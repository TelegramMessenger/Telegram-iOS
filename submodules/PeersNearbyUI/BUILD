load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PeersNearbyUI",
    module_name = "PeersNearbyUI",
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
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/DeviceLocationManager:DeviceLocationManager",
        "//submodules/AlertUI:AlertUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/ItemListPeerItem:ItemListPeerItem",
        "//submodules/TelegramPermissionsUI:TelegramPermissionsUI",
        "//submodules/ItemListPeerActionItem:ItemListPeerActionItem",
        "//submodules/PeersNearbyIconNode:PeersNearbyIconNode",
        "//submodules/Geocoding:Geocoding",
        "//submodules/AppBundle:AppBundle",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/TelegramNotices:TelegramNotices",
    ],
    visibility = [
        "//visibility:public",
    ],
)
