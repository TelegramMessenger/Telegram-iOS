load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatHistoryEntry",
    module_name = "ChatHistoryEntry",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/MergeLists",
        "//submodules/TemporaryCachedPeerDataManager",
        "//submodules/AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
