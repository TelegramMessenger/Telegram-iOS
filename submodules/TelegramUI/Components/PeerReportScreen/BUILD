load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PeerReportScreen",
    module_name = "PeerReportScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/ContextUI",
        "//submodules/UndoUI",
        "//submodules/PresentationDataUtils",
        "//submodules/AlertUI",
        "//submodules/AppBundle",
        "//submodules/TelegramUIPreferences",
        "//submodules/TelegramPermissionsUI",
        "//submodules/Markdown",
        "//submodules/AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode",
        "//submodules/ShareController",
    ],
    visibility = [
        "//visibility:public",
    ],
)
