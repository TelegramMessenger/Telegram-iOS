load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGMyEsims",
    module_name = "NGMyEsims",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/AccountContext:AccountContext",
        "//Vendor/SnapKit:SnapKit",
        "//Nicegram/EsimModule/EsimAuth:EsimAuth",
        "//Nicegram/NGAlert:NGAlert",
        "//Nicegram/NGButton:NGButton",
        "//Nicegram/NGCustomViews:NGCustomViews",
        "//Nicegram/NGLoadingIndicator:NGLoadingIndicator",
        "//Nicegram/NGLocalization:NGLocalization",
        "//Nicegram/NGModels:NGModels",
        "//Nicegram/NGPhoneFormatter:NGPhoneFormatter",
        "//Nicegram/NGMoneyFormatter:NGMoneyFormatter",
        "//Nicegram/NGPurchaseEsim:NGPurchaseEsim",
        "//Nicegram/NGRegionsFormatter:NGRegionsFormatter",
        "//Nicegram/NGRepositories:NGRepositories",
        "//Nicegram/NGSetupEsim:NGSetupEsim",
        "//Nicegram/NGTheme:NGTheme",
        "//Nicegram/NGToast:NGToast",
    ],
    visibility = ["//visibility:public"],

)
