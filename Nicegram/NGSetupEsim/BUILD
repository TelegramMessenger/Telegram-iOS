load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGSetupEsim",
    module_name = "NGSetupEsim",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Vendor/SnapKit:SnapKit",
        "//Nicegram/NGButton:NGButton",
        "//Nicegram/NGCustomViews:NGCustomViews",
        "//Nicegram/NGExtensions:NGExtensions",
        "//Nicegram/NGLocalization:NGLocalization",
        "//Nicegram/NGModels:NGModels",
        "//Nicegram/NGScanQR:NGScanQR",
        "//Nicegram/NGToast:NGToast",
        "//Nicegram/NGTheme:NGTheme",
    ],
    visibility = ["//visibility:public"],

)
