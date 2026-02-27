load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AttachmentFileController",
    module_name = "AttachmentFileController",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/AccountContext",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramStringFormatting",
        "//submodules/TelegramUIPreferences",
        "//submodules/LegacyComponents",
        "//submodules/SolidRoundedButtonNode",
        "//submodules/PresentationDataUtils",
        "//submodules/UIKitRuntimeUtils",
        "//submodules/ComponentFlow",
        "//submodules/ItemListPeerActionItem",
        "//submodules/ListMessageItem",
        "//submodules/AttachmentUI",
        "//submodules/SearchBarNode",
        "//submodules/MergeLists",
        "//submodules/ChatListSearchItemHeader",
        "//submodules/ItemListUI",
        "//submodules/SearchUI",
        "//submodules/ContextUI",
        "//submodules/AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramUI/Components/GlassBarButtonComponent",
        "//submodules/TelegramUI/Components/SearchInputPanelComponent",
        "//submodules/TelegramUI/Components/EdgeEffect",
    ],
    visibility = [
        "//visibility:public",
    ],
)

