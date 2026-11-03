load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "BotSettingsScreen",
    module_name = "BotSettingsScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/ItemListUI",
        "//submodules/ItemListPeerItem",
        "//submodules/AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)

