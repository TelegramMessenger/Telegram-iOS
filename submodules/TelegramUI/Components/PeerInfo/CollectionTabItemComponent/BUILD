load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CollectionTabItemComponent",
    module_name = "CollectionTabItemComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/TextFormat",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramUI/Components/TabSelectorComponent",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView",
    ],
    visibility = [
        "//visibility:public",
    ],
)
