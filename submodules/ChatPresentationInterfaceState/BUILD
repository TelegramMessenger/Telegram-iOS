load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "ChatPresentationInterfaceState",
    module_name = "ChatPresentationInterfaceState",
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
        "//submodules/Postbox:Postbox",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ContextUI:ContextUI",
        "//submodules/ChatInterfaceState:ChatInterfaceState",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ChatContextQuery",
        "//submodules/TooltipUI",
        "//submodules/AudioWaveform",
        "//submodules/UndoUI",
        "//submodules/TextFormat",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ChatPresentationInterfaceStateTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":ChatPresentationInterfaceState",
        "//submodules/TelegramCore",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15.
ios_test_runner(
    name = "ChatPresentationInterfaceStateTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "ChatPresentationInterfaceStateTests",
    minimum_os_version = "15.0",
    runner = ":ChatPresentationInterfaceStateTestRunner",
    deps = [
        ":ChatPresentationInterfaceStateTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
