load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGSubscription",
    module_name = "NGSubscription",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Vendor/SnapKit:SnapKit",
        "//Nicegram/NGButton:NGButton",
        "//Nicegram/NGExtensions:NGExtensions",
        "//Nicegram/SubscriptionAnalytics:SubscriptionAnalytics",
        "//Nicegram/NGLoadingIndicator:NGLoadingIndicator",
        "//Nicegram/NGIAP:NGIAP",
        "//Nicegram/NGEnv:NGEnv",
    ],
    visibility = [
        "//visibility:public",
    ],
)
