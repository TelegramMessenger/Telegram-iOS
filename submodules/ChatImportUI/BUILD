load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatImportUI",
    module_name = "ChatImportUI",
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
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AppBundle:AppBundle",
        "//third-party/ZipArchive:ZipArchive",
        "//submodules/AccountContext:AccountContext",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/RadialStatusNode:RadialStatusNode",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/MimeTypes:MimeTypes",
        "//submodules/ConfettiEffect:ConfettiEffect",
        "//submodules/TelegramUniversalVideoContent:TelegramUniversalVideoContent",
        "//submodules/SolidRoundedButtonNode:SolidRoundedButtonNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
