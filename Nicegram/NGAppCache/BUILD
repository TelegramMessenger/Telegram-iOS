load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGAppCache",
    module_name = "NGAppCache",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/EsimModule/EsimKeychainWrapper:EsimKeychainWrapper",
    ],
    visibility = [
        "//visibility:public",
    ],
)
