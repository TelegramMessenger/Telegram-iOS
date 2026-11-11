load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "TabBarComponent",
    module_name = "TabBarComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/UIKitRuntimeUtils",
        "//submodules/TelegramUI/Components/LiquidLens",
        "//submodules/AppBundle",
        "//submodules/SearchBarNode",
        "//submodules/TelegramUI/Components/TabSelectionRecognizer",
        "//submodules/TelegramUI/Components/TabBarLayout",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "TabBarComponentTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":TabBarComponent",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15.
ios_test_runner(
    name = "TabBarComponentTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "TabBarComponentTests",
    minimum_os_version = "15.0",
    runner = ":TabBarComponentTestRunner",
    deps = [
        ":TabBarComponentTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
