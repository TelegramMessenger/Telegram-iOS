load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WebSearchUI",
    module_name = "WebSearchUI",
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
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/MergeLists:MergeLists",
        "//submodules/GalleryUI:GalleryUI",
        "//submodules/ChatListSearchItemHeader:ChatListSearchItemHeader",
        "//submodules/TelegramUniversalVideoContent:TelegramUniversalVideoContent",
        "//submodules/CheckNode:CheckNode",
        "//submodules/PhotoResources:PhotoResources",
        "//submodules/SearchBarNode:SearchBarNode",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/LegacyMediaPickerUI:LegacyMediaPickerUI",
        "//submodules/SegmentedControlNode:SegmentedControlNode",
        "//submodules/AppBundle:AppBundle",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/AttachmentUI:AttachmentUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
