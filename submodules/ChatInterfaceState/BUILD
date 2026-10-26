load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "ChatInterfaceState",
    module_name = "ChatInterfaceState",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TextFormat:TextFormat",
        "//submodules/AccountContext:AccountContext",
        "//submodules/AudioWaveform",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ChatInterfaceStateTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":ChatInterfaceState",
        "//submodules/TelegramCore:TelegramCore",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15.
ios_test_runner(
    name = "ChatInterfaceStateTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "ChatInterfaceStateTests",
    minimum_os_version = "15.0",
    runner = ":ChatInterfaceStateTestRunner",
    deps = [
        ":ChatInterfaceStateTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
