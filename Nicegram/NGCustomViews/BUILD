load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGCustomViews",
    module_name = "NGCustomViews",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Vendor/SnapKit:SnapKit",
        "//Nicegram/NGButton:NGButton",
        "//Nicegram/NGExtensions:NGExtensions",
        "//Nicegram/NGImageContainer:NGImageContainer",
        "//Nicegram/NGLocalization:NGLocalization",
        "//Nicegram/NGTheme:NGTheme",
        "//submodules/lottie-ios:Lottie",
    ],
    visibility = ["//visibility:public"],
)
