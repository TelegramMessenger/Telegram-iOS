load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LegacyMediaPickerUI",
    module_name = "LegacyMediaPickerUI",
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
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/LegacyUI:LegacyUI",
        "//submodules/MimeTypes:MimeTypes",
        "//submodules/LocalMediaResources:LocalMediaResources",
        "//submodules/SearchPeerMembers:SearchPeerMembers",
        "//submodules/SaveToCameraRoll:SaveToCameraRoll",
        "//submodules/LegacyMediaPickerUI/LegacyImageProcessors:LegacyImageProcessors",
    ],
    visibility = [
        "//visibility:public",
    ],
)
