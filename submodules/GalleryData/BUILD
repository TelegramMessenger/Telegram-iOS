load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "GalleryData",
    module_name = "GalleryData",
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
        "//submodules/AppBundle:AppBundle",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/InstantPageUI:InstantPageUI",
        "//submodules/GalleryUI:GalleryUI",
        "//submodules/PeerAvatarGalleryUI:PeerAvatarGalleryUI",
        "//submodules/MediaResources:MediaResources",
        "//submodules/WebsiteType:WebsiteType",
    ],
    visibility = [
        "//visibility:public",
    ],
)
