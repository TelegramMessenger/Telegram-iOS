load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "OwnershipTransferController",
    module_name = "OwnershipTransferController",
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
        "//submodules/Postbox",
        "//submodules/TelegramPresentationData",
        "//submodules/PresentationDataUtils",
        "//submodules/AccountContext",
        "//submodules/TextFormat",
        "//submodules/AlertUI",
        "//submodules/PasswordSetupUI",
        "//submodules/Markdown",
        "//submodules/ActivityIndicator",
        "//submodules/TelegramUI/Components/PeerManagement/OldChannelsController",
    ],
    visibility = [
        "//visibility:public",
    ],
)
