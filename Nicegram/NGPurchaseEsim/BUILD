load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGPurchaseEsim",
    module_name = "NGPurchaseEsim",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/AccountContext:AccountContext",
        "//Vendor/SnapKit:SnapKit",
        "//Nicegram/EsimModule/EsimApiClient:EsimApiClient",
        "//Nicegram/EsimModule/EsimAuth:EsimAuth",
	    "//Nicegram/EsimModule/EsimMobileDataPayments:EsimMobileDataPayments",
	    "//Nicegram/EsimModule/EsimMobileDataPurchaseProvider:EsimMobileDataPurchaseProvider",
        "//Nicegram/NGAlert:NGAlert",
        "//Nicegram/NGAppContext:NGAppContext",
        "//Nicegram/NGAuth:NGAuth",
        "//Nicegram/NGButton:NGButton",
        "//Nicegram/NGCoreUI:NGCoreUI",
        "//Nicegram/NGCountriesList:NGCountriesList",
        "//Nicegram/NGCustomViews:NGCustomViews",
        "//Nicegram/NGLoadingIndicator:NGLoadingIndicator",
        "//Nicegram/NGLocalization:NGLocalization",
        "//Nicegram/NGMappers:NGMappers",
        "//Nicegram/NGMobileDataFormatter:NGMobileDataFormatter",
        "//Nicegram/NGModels:NGModels",
        "//Nicegram/NGPicker:NGPicker",
        "//Nicegram/NGMoneyFormatter:NGMoneyFormatter",
        "//Nicegram/NGRegionsFormatter:NGRegionsFormatter",
        "//Nicegram/NGRepositories:NGRepositories",
        "//Nicegram/NGTheme:NGTheme",
        "//Nicegram/NGEnv:NGEnv"
    ],
    visibility = ["//visibility:public"],

)
