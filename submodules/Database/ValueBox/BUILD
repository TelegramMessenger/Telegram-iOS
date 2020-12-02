load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ValueBox",
    module_name = "ValueBox",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/sqlcipher:sqlcipher",
        "//submodules/Database/Buffers:Buffers",
    ],
    visibility = [
        "//visibility:public",
    ],
)
