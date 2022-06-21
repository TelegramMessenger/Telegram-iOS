load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WebsiteType",
    module_name = "WebsiteType",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
