load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WallpaperResources",
    module_name = "WallpaperResources",
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
        "//submodules/LocalMediaResources:LocalMediaResources",
        "//submodules/TinyThumbnail:TinyThumbnail",
        "//submodules/ImageBlur:ImageBlur",
        "//submodules/MediaResources:MediaResources",
        "//submodules/PhotoResources:PhotoResources",
        "//submodules/PersistentStringHash:PersistentStringHash",
        "//submodules/AppBundle:AppBundle",
        "//submodules/Svg:Svg",
        "//submodules/GZip:GZip",
        "//submodules/GradientBackground:GradientBackground",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
    ],
    visibility = [
        "//visibility:public",
    ],
)
