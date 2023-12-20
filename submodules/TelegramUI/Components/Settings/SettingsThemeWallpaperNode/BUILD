load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SettingsThemeWallpaperNode",
    module_name = "SettingsThemeWallpaperNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/GradientBackground",
        "//submodules/WallpaperResources",
        "//submodules/StickerResources",
        "//submodules/AccountContext",
        "//submodules/RadialStatusNode",
        "//submodules/AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
