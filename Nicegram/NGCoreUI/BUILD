load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGCoreUI",
    module_name = "NGCoreUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Vendor/SnapKit:SnapKit",
        "//Nicegram/NGAlert:NGAlert",
        "//Nicegram/NGButton:NGButton",
        "//Nicegram/NGCore:NGCore",
        "//Nicegram/NGCustomViews:NGCustomViews",
        "//Nicegram/NGLoadingIndicator:NGLoadingIndicator",
        "//Nicegram/NGLocalization:NGLocalization",
		"//Nicegram/NGMoneyFormatter:NGMoneyFormatter",
        "//Nicegram/NGToast:NGToast",
        "//submodules/Markdown:Markdown",
    ],
    visibility = [
        "//visibility:public",
    ],
)
