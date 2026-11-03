load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NewsChannelIsland",
    module_name = "NewsChannelIsland",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/AppBundle",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/News/NewsFeedSupport",
    ],
    visibility = [
        "//visibility:public",
    ],
)
