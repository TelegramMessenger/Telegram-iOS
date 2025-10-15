load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PlatformRestrictionMatching",
    module_name = "PlatformRestrictionMatching",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Postbox:Postbox",
    ],
    visibility = [
        "//visibility:public",
    ],
)
