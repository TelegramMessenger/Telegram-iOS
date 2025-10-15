load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SpotlightSupport",
    module_name = "SpotlightSupport",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/SyncCore:SyncCore",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Display:Display",
    ],
    visibility = [
        "//visibility:public",
    ],
)
