load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CloudData",
    module_name = "CloudData",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/EncryptionProvider:EncryptionProvider",
    ],
    visibility = [
        "//visibility:public",
    ],
)
