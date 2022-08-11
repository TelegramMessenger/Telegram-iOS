load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGPicker",
    module_name = "NGPicker",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
	    "//Vendor/SnapKit:SnapKit",
        "//submodules/lottie-ios:Lottie",
        "//Nicegram/NGExtensions:NGExtensions",
        "//Nicegram/NGTheme:NGTheme",
    ],
    visibility = [
        "//visibility:public",
    ],
)
