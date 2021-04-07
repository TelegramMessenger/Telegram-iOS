load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SyncCore",
    module_name = "SyncCore",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
    ],
    visibility = [
        "//visibility:public",
    ],
)
