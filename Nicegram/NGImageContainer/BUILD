load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGImageContainer",
    module_name = "NGImageContainer",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Vendor/SnapKit:SnapKit",
    ],
    visibility = ["//visibility:public"],

)
