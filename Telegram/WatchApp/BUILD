# Committed snapshot of the tgwatch watch app (synced from the standalone tgwatch repo
# via tools/export-sources.sh). Built by //Telegram:TelegramWatchApp
# (apple_prebuilt_watchos_application) via xcodebuild. These files are the rule's tracked
# inputs, so the watch build re-runs only when the snapshot changes.
filegroup(
    name = "sources",
    srcs = glob(
        ["**"],
        exclude = [
            "**/.build/**",
            "**/.swiftpm/**",
            "**/xcuserdata/**",
            "**/DerivedData/**",
            "BUILD",
            ".gitignore",
        ],
    ),
    visibility = ["//Telegram:__pkg__"],
)
