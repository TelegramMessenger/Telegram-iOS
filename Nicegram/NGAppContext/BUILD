load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGAppContext",
    module_name = "NGAppContext",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/NGApiClient:NGApiClient",
        "//Nicegram/NGAuth:NGAuth",
        "//Nicegram/NGLottery:NGLottery",
        "//Nicegram/NGSubscription:NGSubscription",
        "//Nicegram/NGTelegramRepo:NGTelegramRepo",
    ],
    visibility = [
        "//visibility:public",
    ],
)
