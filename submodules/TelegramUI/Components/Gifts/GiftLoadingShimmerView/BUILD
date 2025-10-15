load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "GiftLoadingShimmerView",
    module_name = "GiftLoadingShimmerView",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/MultilineTextWithEntitiesComponent",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/TelegramStringFormatting",
        "//submodules/PresentationDataUtils",
        "//submodules/TextFormat",
        "//submodules/Markdown",
        "//submodules/AvatarNode",
        "//submodules/CheckNode",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView",
        "//submodules/TelegramUI/Components/Stars/ItemShimmeringLoadingComponent",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoCoverComponent",
        "//submodules/Components/BundleIconComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
