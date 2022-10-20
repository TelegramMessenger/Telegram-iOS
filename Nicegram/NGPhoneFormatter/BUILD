load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGPhoneFormatter",
    module_name = "NGPhoneFormatter",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/libphonenumber:libphonenumber",
    ],
    visibility = ["//visibility:public"],

)
