load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGButton",
    module_name = "NGButton",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Vendor/SnapKit:SnapKit",
        "//Nicegram/NGImageContainer:NGImageContainer",
        "//Nicegram/NGTheme:NGTheme",
    ],
    visibility = ["//visibility:public"],

)
