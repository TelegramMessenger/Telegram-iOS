load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGScanQR",
    module_name = "NGScanQR",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Vendor/SnapKit:SnapKit",
        "//Nicegram/NGButton:NGButton",
        "//Nicegram/NGCustomViews:NGCustomViews",
        "//Nicegram/NGExtensions:NGExtensions",
        "//Nicegram/NGLocalization:NGLocalization",
        "//Nicegram/NGTheme:NGTheme",
    ],
    visibility = ["//visibility:public"],

)
