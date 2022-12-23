load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGLotteryUI",
    module_name = "NGLotteryUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/NGAppContext:NGAppContext",
        "//Nicegram/NGAuth:NGAuth",
        "//Nicegram/NGCoreUI:NGCoreUI",
		"//Nicegram/NGSubscription:NGSubscription",
    ],
    visibility = [
        "//visibility:public",
    ],
)
