load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PostboxCoding",
    module_name = "PostboxCoding",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/Database/Buffers:Buffers",
        "//submodules/Database/MurmurHash:MurmurHash",
    ],
    visibility = [
        "//visibility:public",
    ],
)
