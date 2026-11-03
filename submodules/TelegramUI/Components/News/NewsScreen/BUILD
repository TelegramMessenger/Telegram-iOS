load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NewsScreen",
    module_name = "NewsScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/ContextUI",
        "//submodules/SearchUI",
        "//submodules/SearchBarNode",
        "//submodules/LocalizedPeerData",
        "//submodules/TelegramUI/Components/ChatListHeaderComponent",
        "//submodules/TelegramUI/Components/NavigationBarComponent",
        "//submodules/TelegramUI/Components/ChatListTitleView",
        "//submodules/TelegramUI/Components/HorizontalTabsComponent",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/LottieSettings",
        "//submodules/TelegramUI/Components/EdgeEffect",
        "//submodules/TelegramUI/Components/CoreList:CoreList",
        "//submodules/TelegramUI/Components/CoreListComponentHost",
        "//submodules/TelegramUI/Components/News/NewsFeedSupport",
        "//submodules/TelegramUI/Components/News/NewsFeedComponents",
    ],
    visibility = [
        "//visibility:public",
    ],
)
