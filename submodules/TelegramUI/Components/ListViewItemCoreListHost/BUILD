load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "ListViewItemCoreListHost",
    module_name = "ListViewItemCoreListHost",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters:ComponentDisplayAdapters",
        "//submodules/TelegramUI/Components/CoreList:CoreList",
        "//submodules/TelegramUI/Components/CoreListComponentHost",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ListViewItemCoreListHostTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":ListViewItemCoreListHost",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/TelegramUI/Components/CoreList:CoreList",
    ],
)

ios_test_runner(
    name = "ListViewItemCoreListHostTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "ListViewItemCoreListHostTests",
    env = {"REUSE_GLOBAL_SIMULATOR": "1"},
    minimum_os_version = "15.0",
    runner = ":ListViewItemCoreListHostTestRunner",
    deps = [
        ":ListViewItemCoreListHostTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
