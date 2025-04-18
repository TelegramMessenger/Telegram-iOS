load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WatchBridge",
    module_name = "WatchBridge",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/SSignalKit/SSignalKit:SSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/WatchCommon/Host:WatchCommon",
        "//submodules/WatchBridgeAudio:WatchBridgeAudio",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/AccountContext:AccountContext",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/StickerResources:StickerResources",
        "//submodules/PhotoResources:PhotoResources",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/LegacyUI:LegacyUI",
        "//submodules/PhoneNumberFormat:PhoneNumberFormat",
    	"//submodules/WatchBridge/Impl:WatchBridgeImpl",
    ],
    visibility = [
        "//visibility:public",
    ],
)
