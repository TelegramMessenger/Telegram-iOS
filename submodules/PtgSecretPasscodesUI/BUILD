load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PtgSecretPasscodesUI",
    module_name = "PtgSecretPasscodesUI",
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
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/SettingsUI:SettingsUI",
        "//submodules/PtgSecretPasscodes:PtgSecretPasscodes",
    ],
    visibility = [
        "//visibility:public",
    ],
)
