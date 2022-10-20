load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGToast",
    module_name = "NGToast",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Vendor/SnapKit:SnapKit",
        "//Nicegram/NGExtensions:NGExtensions",
        "//Nicegram/NGLocalization:NGLocalization",
    ],
    visibility = ["//visibility:public"],

)
