load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGTheme",
    module_name = "NGTheme",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/Display:Display",
        "//Nicegram/NGExtensions:NGExtensions",
    ],
    visibility = ["//visibility:public"],

)
