load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGLottery",
    module_name = "NGLottery",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/NGAuth:NGAuth",
        "//Nicegram/NGCore:NGCore",
        "//Nicegram/NGEnv:NGEnv",
        "//Nicegram/NGStoreKitFacade:NGStoreKitFacade",
        "//Nicegram/NGUtils:NGUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
