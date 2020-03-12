load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ContactListUI",
    module_name = "ContactListUI",
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
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/MergeLists:MergeLists",
        "//submodules/SearchUI:SearchUI",
        "//submodules/ChatListSearchItemHeader:ChatListSearchItemHeader",
        "//submodules/ItemListPeerItem:ItemListPeerItem",
        "//submodules/ContactsPeerItem:ContactsPeerItem",
        "//submodules/ChatListSearchItemNode:ChatListSearchItemNode",
        "//submodules/TelegramPermissionsUI:TelegramPermissionsUI",
        "//submodules/TelegramNotices:TelegramNotices",
        "//submodules/AlertUI:AlertUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/ShareController:ShareController",
        "//submodules/AppBundle:AppBundle",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/PhoneNumberFormat:PhoneNumberFormat",
        "//submodules/SolidRoundedButtonNode:SolidRoundedButtonNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
