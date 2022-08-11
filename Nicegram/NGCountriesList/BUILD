load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGCountriesList",
    module_name = "NGCountriesList",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Vendor/SnapKit:SnapKit",
        "//Nicegram/NGCustomViews:NGCustomViews",
        "//Nicegram/NGLocalization:NGLocalization",
        "//Nicegram/NGMobileDataFormatter:NGMobileDataFormatter",
        "//Nicegram/NGModels:NGModels",
        "//Nicegram/NGMoneyFormatter:NGMoneyFormatter",
        "//Nicegram/NGRegionsFormatter:NGRegionsFormatter",
        "//Nicegram/NGSearch:NGSearch",
        "//Nicegram/NGTheme:NGTheme",
    ],
    visibility = ["//visibility:public"],

)
