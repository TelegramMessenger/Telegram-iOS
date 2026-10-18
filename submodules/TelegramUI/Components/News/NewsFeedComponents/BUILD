load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NewsFeedComponents",
    module_name = "NewsFeedComponents",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Components/HierarchyTrackingLayer",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/TelegramStringFormatting",
        "//submodules/TextFormat",
        "//submodules/PhotoResources",
        "//submodules/ShimmerEffect",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/MultilineTextWithEntitiesComponent",
        "//submodules/TelegramUI/Components/AvatarComponent",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/TelegramUI/Components/News/NewsFeedSupport",
        "//submodules/ItemListUI",
        "//submodules/LottieBinding",
        "//submodules/LottieSettings",
        "//submodules/GZip",
        "//submodules/AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
