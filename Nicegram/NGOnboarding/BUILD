load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGOnboarding",
    module_name = "NGOnboarding",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/NGButton:NGButton",
        "//Nicegram/NGData:NGData",
        "//Nicegram/NGSubscription:NGSubscription",
        "//Nicegram/NGUIUtils:NGUIUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
