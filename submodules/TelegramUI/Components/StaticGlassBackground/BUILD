load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

# Images captured from iOS 27 glass, in place of live glass where the chat shows it per message (bubble mode off).
# The assets are submodules/TelegramUI/Resources/StaticGlass/*.bin, made by Tools/make_static_glass.py from captures
# of Tests/GlassCapture.
swift_library(
    name = "StaticGlassBackground",
    module_name = "StaticGlassBackground",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "StaticGlassBackgroundTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":StaticGlassBackground",
    ],
)

ios_test_runner(
    name = "StaticGlassBackgroundTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "StaticGlassBackgroundTests",
    minimum_os_version = "15.0",
    runner = ":StaticGlassBackgroundTestRunner",
    deps = [
        ":StaticGlassBackgroundTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
