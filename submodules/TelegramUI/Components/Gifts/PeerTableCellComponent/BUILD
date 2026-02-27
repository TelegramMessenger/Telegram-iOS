load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PeerTableCellComponent",
    module_name = "PeerTableCellComponent",
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
        "//submodules/ComponentFlow",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramCore",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/AccountContext",
        "//submodules/AvatarNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
