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
