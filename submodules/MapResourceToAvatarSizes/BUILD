load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MapResourceToAvatarSizes",
    module_name = "MapResourceToAvatarSizes",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SyncCore:SyncCore",
        "//submodules/Display:Display",
    ],
    visibility = [
        "//visibility:public",
    ],
)
