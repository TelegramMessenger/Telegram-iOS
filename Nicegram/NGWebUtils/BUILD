load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGWebUtils",
    module_name = "NGWebUtils",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/NGData:NGData",
        "//submodules/Postbox:Postbox",
        "//submodules/SyncCore:SyncCore",
        "//submodules/TelegramCore:TelegramCore"
    ],
    visibility = [
        "//visibility:public",
    ],
)
