load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")


filegroup(
    name = "NGUIAssets",
    srcs = glob(["Images.xcassets/**"]),
    visibility = ["//visibility:public"],
)

swift_library(
    name = "NGUI",
    module_name = "NGUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/Postbox:Postbox",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramNotices:TelegramNotices",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/PeersNearbyIconNode:PeersNearbyIconNode",
        "//submodules/TelegramPermissionsUI:TelegramPermissionsUI",
        "//submodules/TranslateUI:TranslateUI",
        "//submodules/UndoUI:UndoUI",
        "//submodules/ContextUI:ContextUI",
        "//Nicegram/NGData:NGData",
        "//Nicegram/NGLogging:NGLogging",
        "//Nicegram/NGStrings:NGStrings",
        "//Nicegram/NGIAP:NGIAP",
        "//Nicegram/NGAssistant:NGAssistant",
        "//Nicegram/NGAppCache:NGAppCache",
        "//Nicegram/NGLoadingIndicator:NGLoadingIndicator",
        "//Nicegram/NGWebUtils:NGWebUtils",
        "//Nicegram/NGEnv:NGEnv",
        "//Nicegram/NGDoubleBottom:NGDoubleBottom",
        "//Nicegram/NGQuickReplies:NGQuickReplies",
        "//Nicegram/NGSecretMenu:NGSecretMenu",
        "//Nicegram/NGStats:NGStats",
    ],
    visibility = [
        "//visibility:public",
    ],
)
