load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGDoubleBottom",
    module_name = "NGDoubleBottom",
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
        "//submodules/UndoUI:UndoUI",
        "//submodules/ContextUI:ContextUI",
        "//submodules/PasscodeUI:PasscodeUI",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//Nicegram/NGData:NGData",
        "//Nicegram/NGLogging:NGLogging",
        "//Nicegram/NGStrings:NGStrings",
        "//Nicegram/NGIAP:NGIAP",
        "//Nicegram/NGAssistant:NGAssistant",
        "//Nicegram/NGAppCache:NGAppCache",
        "//Nicegram/NGEnv:NGEnv",
    ],
    visibility = [
        "//visibility:public",
    ],
)
