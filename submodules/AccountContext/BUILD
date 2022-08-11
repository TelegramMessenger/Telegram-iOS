load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

NGDEPS = ["//Nicegram/NGModels:NGModels"]

swift_library(
    name = "AccountContext",
    module_name = "AccountContext",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = NGDEPS + [
        "//submodules/TelegramAudio:TelegramAudio",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/TemporaryCachedPeerDataManager:TemporaryCachedPeerDataManager",
        "//submodules/DeviceLocationManager:DeviceLocationManager",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/MusicAlbumArtResources:MusicAlbumArtResources",
        "//submodules/MeshAnimationCache:MeshAnimationCache",
        "//submodules/Utils/RangeSet:RangeSet",
        "//submodules/InAppPurchaseManager:InAppPurchaseManager",
    ],
    visibility = [
        "//visibility:public",
    ],
)
