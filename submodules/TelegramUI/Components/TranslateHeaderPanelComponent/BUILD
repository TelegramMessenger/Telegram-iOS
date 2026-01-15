load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TranslateHeaderPanelComponent",
    module_name = "TranslateHeaderPanelComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/LocalizedPeerData",
        "//submodules/TelegramStringFormatting",
        "//submodules/TextFormat",
        "//submodules/Markdown",
        "//submodules/MoreButtonNode",
        "//submodules/ContextUI",
        "//submodules/TranslateUI",
        "//submodules/TelegramUIPreferences",
        "//submodules/TelegramNotices",
        "//submodules/PremiumUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
