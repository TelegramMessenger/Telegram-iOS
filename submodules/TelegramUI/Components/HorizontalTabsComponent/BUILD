load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "HorizontalTabsComponent",
    module_name = "HorizontalTabsComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/AsyncDisplayKit",
        "//submodules/AnimationUI",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/Components/MultilineTextWithEntitiesComponent",
        "//submodules/TelegramUI/Components/LiquidLens",
        "//submodules/TelegramUI/Components/TextBadgeComponent",
        "//submodules/TelegramUI/Components/HeaderPanelContainerComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "HorizontalTabsComponentTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":HorizontalTabsComponent",
        "//submodules/ComponentFlow",
        "//submodules/TelegramPresentationData",
        "//submodules/Components/MultilineTextWithEntitiesComponent",
        "//submodules/TelegramUI/Components/LiquidLens",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15.
ios_test_runner(
    name = "HorizontalTabsComponentTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "HorizontalTabsComponentTests",
    minimum_os_version = "15.0",
    runner = ":HorizontalTabsComponentTestRunner",
    deps = [
        ":HorizontalTabsComponentTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
