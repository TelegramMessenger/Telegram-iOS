load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "StoryLiveChatMessageComponent",
    module_name = "StoryLiveChatMessageComponent",
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
        "//submodules/Components/BundleIconComponent",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/MultilineTextWithEntitiesComponent",
        "//submodules/AvatarNode",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUI/Components/StarsParticleEffect",
        "//submodules/TelegramUI/Components/PeerNameTextComponent",
        "//submodules/TextFormat",
    ],
    visibility = [
        "//visibility:public",
    ],
)
