load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MusicAlbumArtResources",
    module_name = "MusicAlbumArtResources",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
    	"//submodules/TelegramCore:TelegramCore",
        "//submodules/SyncCore:SyncCore",
    	"//submodules/Postbox:Postbox",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/UrlEscaping:UrlEscaping",
    ],
    visibility = [
        "//visibility:public",
    ],
)
