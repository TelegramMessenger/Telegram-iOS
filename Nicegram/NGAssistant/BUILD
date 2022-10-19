load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGAssistant",
    module_name = "NGAssistant",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Vendor/SnapKit:SnapKit",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//Nicegram/EsimModule/EsimAuth:EsimAuth",
        "//Nicegram/NGAuth:NGAuth",
        "//Nicegram/NGLoadingIndicator:NGLoadingIndicator",
        "//Nicegram/NGButton:NGButton",
        "//Nicegram/NGExtensions:NGExtensions",
        "//Nicegram/NGSecondPhone:NGSecondPhone",
        "//Nicegram/NGCustomViews:NGCustomViews",
        "//Nicegram/NGLocalization:NGLocalization",
        "//Nicegram/NGLogging:NGLogging",
        "//Nicegram/NGMyEsims:NGMyEsims",
        "//Nicegram/NGSpecialOffer:NGSpecialOffer",
        "//Nicegram/NGTheme:NGTheme",
        "//Nicegram/NGToast:NGToast",
    ],
    visibility = ["//visibility:public"],

)
