load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PhotoResources",
    module_name = "PhotoResources",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Postbox:Postbox",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/ImageTransparency:ImageTransparency",
        "//submodules/TinyThumbnail:TinyThumbnail",
        "//submodules/ImageBlur:ImageBlur",
        "//submodules/Tuples:Tuples",
        "//submodules/AccountContext:AccountContext",
        "//submodules/MediaResources:MediaResources",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/WebPBinding:WebPBinding",
        "//submodules/AppBundle:AppBundle",
        "//submodules/MusicAlbumArtResources:MusicAlbumArtResources",
        "//submodules/Svg:Svg",
    ],
    visibility = [
        "//visibility:public",
    ],
)
