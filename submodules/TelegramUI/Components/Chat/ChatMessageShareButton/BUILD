load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageShareButton",
    module_name = "ChatMessageShareButton",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/ContextUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
