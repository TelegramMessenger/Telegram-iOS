load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGAlert",
    module_name = "NGAlert",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Vendor/SnapKit:SnapKit",
        "//Nicegram/EsimModule/EsimUI:EsimUI",
        "//Nicegram/NGButton:NGButton",
        "//Nicegram/NGCustomViews:NGCustomViews",
        "//Nicegram/NGExtensions:NGExtensions",
        "//Nicegram/NGLocalization:NGLocalization",
        "//Nicegram/NGTheme:NGTheme",
    ],
    visibility = ["//visibility:public"],

)
