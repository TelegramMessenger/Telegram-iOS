load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TelegramCallsUI",
    module_name = "TelegramCallsUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
    	"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/PhotoResources:PhotoResources",
        "//submodules/TelegramNotices:TelegramNotices",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/DeviceAccess:DeviceAccess",
        "//submodules/TelegramAudio:TelegramAudio",
        "//submodules/TelegramVoip:TelegramVoip",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/AppBundle:AppBundle",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/TelegramCallsUI/CallsEmoji:CallsEmoji",
    ],
    visibility = [
        "//visibility:public",
    ],
)
