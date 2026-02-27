load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "GroupCallHeaderPanelComponent",
    module_name = "GroupCallHeaderPanelComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/TelegramUIPreferences",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/GlobalControlPanelsContext",
        "//submodules/PresentationDataUtils",
        "//submodules/TextFormat",
        "//submodules/Markdown",
        "//submodules/LocalizedPeerData",
        "//submodules/LiveLocationTimerNode",
        "//submodules/TelegramStringFormatting",
        "//submodules/AppBundle",
        "//submodules/AnimatedAvatarSetNode",
        "//submodules/AudioBlob",
        "//submodules/TelegramCallsUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
