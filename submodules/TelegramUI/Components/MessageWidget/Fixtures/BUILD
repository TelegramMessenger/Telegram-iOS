load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_bundle")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")

filegroup(
    name = "WidgetFixtures",
    testonly = True,
    srcs = glob(["*.html"]),
    visibility = ["//submodules/TelegramUI/Components/MessageWidget:__subpackages__"],
)

# Single files, so a cc_test can name one in `$(location …)` and derive the directory from it.
exports_files(
    glob(["*.html"]),
    visibility = ["//submodules/TelegramUI/Components/MessageWidget:__subpackages__"],
)

plist_fragment(
    name = "WidgetGamesInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.WidgetGames</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>WidgetGames</string>
    """
)

# DEBUG app builds only (Debug Settings ▸ "Insert widget games"): the game examples, to play with several fingers.
apple_resource_bundle(
    name = "WidgetGamesBundle",
    bundle_name = "WidgetGames",
    infoplists = [":WidgetGamesInfoPlist"],
    resources = ["11-tetris.html", "12-invaders.html", "13-mario-super-lite.html", "14-pacman.html"],
    visibility = ["//submodules/TelegramUI:__pkg__"],
)
