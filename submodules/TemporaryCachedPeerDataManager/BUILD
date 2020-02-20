load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TemporaryCachedPeerDataManager",
    module_name = "TemporaryCachedPeerDataManager",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SyncCore:SyncCore",
        "//submodules/Postbox:Postbox",
    ],
    visibility = [
        "//visibility:public",
    ],
)
