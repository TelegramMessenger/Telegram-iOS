load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FakePasscode",
    module_name = "FakePasscode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramIntents:TelegramIntents",
    ],
    visibility = [
        "//visibility:public",
    ],
)
