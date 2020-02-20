load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TelegramVoip",
    module_name = "TelegramVoip",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SyncCore:SyncCore",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/libtgvoip:libtgvoip",
    ],
    visibility = [
        "//visibility:public",
    ],
)
