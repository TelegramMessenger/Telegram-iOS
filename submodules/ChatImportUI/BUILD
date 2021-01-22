load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatImportUI",
    module_name = "ChatImportUI",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/Postbox:Postbox",
        "//submodules/SyncCore:SyncCore",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AppBundle:AppBundle",
        "//third-party/ZIPFoundation:ZIPFoundation",
        "//submodules/AccountContext:AccountContext",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/RadialStatusNode:RadialStatusNode",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/ChatHistoryImportTasks:ChatHistoryImportTasks",
        "//submodules/MimeTypes:MimeTypes",
    ],
    visibility = [
        "//visibility:public",
    ],
)
