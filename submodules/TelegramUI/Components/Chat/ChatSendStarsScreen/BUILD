load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatSendStarsScreen",
    module_name = "ChatSendStarsScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/ContextUI",
        "//submodules/AppBundle",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/Markdown",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
        "//submodules/TelegramUI/Components/SliderComponent",
        "//submodules/TelegramUI/Components/Utils/RoundedRectWithTailPath",
        "//submodules/TelegramUI/Components/CheckComponent",
        "//submodules/AvatarNode",
        "//submodules/Components/BundleIconComponent",
        "//submodules/CheckNode",
        "//submodules/TextFormat",
    ],
    visibility = [
        "//visibility:public",
    ],
)
