load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "InstantPageUI",
    module_name = "InstantPageUI",
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
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/GalleryUI:GalleryUI",
        "//submodules/MusicAlbumArtResources:MusicAlbumArtResources",
        "//submodules/LiveLocationPositionNode:LiveLocationPositionNode",
        "//submodules/MosaicLayout:MosaicLayout",
        "//submodules/LocationUI:LocationUI",
        "//submodules/AppBundle:AppBundle",
        "//submodules/LocationResources:LocationResources",
        "//submodules/UndoUI:UndoUI",
        "//submodules/TranslateUI:TranslateUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
