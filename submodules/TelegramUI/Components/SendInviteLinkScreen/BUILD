load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SendInviteLinkScreen",
    module_name = "SendInviteLinkScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/TelegramStringFormatting",
        "//submodules/PresentationDataUtils",
        "//submodules/Components/SolidRoundedButtonComponent",
        "//submodules/AvatarNode",
        "//submodules/CheckNode",
        "//submodules/Markdown",
        "//submodules/PeerPresenceStatusManager",
        "//submodules/UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
