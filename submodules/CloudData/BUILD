load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CloudData",
    module_name = "CloudData",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/EncryptionProvider:EncryptionProvider",
    ],
    visibility = [
        "//visibility:public",
    ],
)
