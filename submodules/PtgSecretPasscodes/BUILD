load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PtgSecretPasscodes",
    module_name = "PtgSecretPasscodes",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AppLockState:AppLockState",
    ],
    visibility = [
        "//visibility:public",
    ],
)
