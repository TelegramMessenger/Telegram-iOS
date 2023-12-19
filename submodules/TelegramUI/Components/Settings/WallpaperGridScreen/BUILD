load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WallpaperGridScreen",
    module_name = "WallpaperGridScreen",
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
        "//submodules/PresentationDataUtils",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/ComponentFlow",
        "//submodules/SolidRoundedButtonNode",
        "//submodules/AppBundle",
        "//submodules/PremiumUI",
        "//submodules/WallpaperResources",
        "//submodules/HexColor",
        "//submodules/MergeLists",
        "//submodules/ShareController",
        "//submodules/GalleryUI",
        "//submodules/GridMessageSelectionNode",
        "//submodules/SearchUI",
        "//submodules/MediaPickerUI",
        "//submodules/ItemListPeerActionItem",
        "//submodules/TelegramUI/Components/Settings/WallpaperGalleryScreen",
        "//submodules/TelegramUI/Components/Settings/SettingsThemeWallpaperNode",
        "//submodules/TelegramUI/Components/Settings/ThemeAccentColorScreen",
        "//submodules/TelegramUI/Components/PremiumLockButtonSubtitleComponent",
        "//submodules/TelegramUI/Components/Settings/BoostLevelIconComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
