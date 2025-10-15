load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EmojiActionIconComponent",
    module_name = "EmojiActionIconComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramCore",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
        "//submodules/AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
