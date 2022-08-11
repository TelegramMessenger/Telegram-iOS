load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGLogging",
    module_name = "NGLogging",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
		"@FirebaseSDK//:FirebaseAnalytics",
        "//submodules/TelegramCore:TelegramCore"
    ],
    visibility = [
        "//visibility:public",
    ],
)
