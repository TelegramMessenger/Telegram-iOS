load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "MediaCropComponent",
    module_name = "MediaCropComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramUI/Components/MediaEditor",
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "MediaCropComponentTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":MediaCropComponent",
        "//submodules/TelegramUI/Components/MediaEditor",
    ],
)

ios_test_runner(
    name = "MediaCropComponentTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "MediaCropComponentTests",
    minimum_os_version = "15.0",
    runner = ":MediaCropComponentTestRunner",
    deps = [
        ":MediaCropComponentTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
