load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PeerInfoChatPaneNode",
    module_name = "PeerInfoChatPaneNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/TelegramStringFormatting",
        "//submodules/ComponentFlow",
        "//submodules/AppBundle",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoPaneNode",
        "//submodules/ContextUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
