load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TPStrings",
    module_name = "TPStrings",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)

filegroup(
    name = "TPLocalizableStrings",
    srcs = glob(["Resources/*.lproj/TPLocalizable.strings"]),
    visibility = [
        "//visibility:public",
    ],
)
