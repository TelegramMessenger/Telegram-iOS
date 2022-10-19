load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGAuth",
    module_name = "NGAuth",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/AccountContext:AccountContext",
        "//Nicegram/EsimModule/EsimAuth:EsimAuth",
        "//Vendor/SnapKit:SnapKit",
        "//Nicegram/NGTextFields:NGTextFields",
        "//Nicegram/NGApiClient:NGApiClient",
        "//Nicegram/NGButton:NGButton",
        "//Nicegram/NGExtensions:NGExtensions",
        "//Nicegram/NGCustomViews:NGCustomViews",
        "//Nicegram/NGLocalization:NGLocalization",
        "//Nicegram/NGTheme:NGTheme",
        "//Nicegram/NGEnv:NGEnv",
        "//Nicegram/NGLoadingIndicator:NGLoadingIndicator",
        "//Nicegram/NGToast:NGToast",
        "//Nicegram/NGAlert:NGAlert",
    ],
    visibility = ["//visibility:public"],

)
