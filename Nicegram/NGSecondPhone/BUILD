load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGSecondPhone",
    module_name = "NGSecondPhone",
    srcs = glob([
        "VirtualNumbers/**/*.swift",
    ]),
    deps = [
        "//Vendor/SnapKit:SnapKit",
        "//Nicegram/NGTextFields:NGTextFields",
        "//Nicegram/NGButton:NGButton",
        "//Nicegram/NGExtensions:NGExtensions",
        "//Nicegram/NGCustomViews:NGCustomViews",
    ],
    visibility = ["//visibility:public"],

)
