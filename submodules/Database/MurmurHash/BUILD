load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MurmurHash",
    module_name = "MurmurHash",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/Database/MurmurHash/Impl:MurMurHashObjC",
    ],
    visibility = [
        "//visibility:public",
    ],
)
