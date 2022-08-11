load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGAlert",
    module_name = "NGAlert",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Vendor/SnapKit:SnapKit",
        "//Nicegram/NGButton:NGButton",
        "//Nicegram/NGExtensions:NGExtensions",
        "//Nicegram/NGLocalization:NGLocalization",
        "//Nicegram/NGTheme:NGTheme",
        "//Nicegram/NGTransitions:NGTransitions",
    ],
    visibility = ["//visibility:public"],

)
