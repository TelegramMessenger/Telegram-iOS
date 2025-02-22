load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessagePaymentAlertController",
    module_name = "ChatMessagePaymentAlertController",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ComponentFlow",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/TextFormat",
        "//submodules/AvatarNode",
        "//submodules/CheckNode",
        "//submodules/TelegramUIPreferences",
        "//submodules/TelegramUI/Components/Stars/StarsBalanceOverlayComponent",
        "//submodules/Markdown",
    ],
    visibility = [
        "//visibility:public",
    ],
)
