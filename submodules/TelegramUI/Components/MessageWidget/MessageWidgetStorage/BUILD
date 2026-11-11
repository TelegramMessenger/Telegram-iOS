load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

# A message widget's storage on the client's side (SDK v1 §2.8, §5.4): kept in memory and written into the message's
# derived data (DerivedDataMessageAttribute["widget"]), with an index of those messages for "Clear cache".
swift_library(
    name = "MessageWidgetStorage",
    module_name = "MessageWidgetStorage",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramUIPreferences",
        "//submodules/TelegramUI/Components/MessageWidget/MessageWidget",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "MessageWidgetStorageTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":MessageWidgetStorage",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramUI/Components/MessageWidget/MessageWidget",
    ],
)

ios_test_runner(
    name = "MessageWidgetStorageTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "MessageWidgetStorageTests",
    minimum_os_version = "15.0",
    runner = ":MessageWidgetStorageTestRunner",
    deps = [
        ":MessageWidgetStorageTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
