load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageActionButtonsNode",
    module_name = "ChatMessageActionButtonsNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/UrlHandling",
        "//submodules/TelegramUI/Components/TextLoadingEffect",
    ],
    visibility = [
        "//visibility:public",
    ],
)
