load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "LegacyMessageInputPanel",
    module_name = "LegacyMessageInputPanel",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/AccountContext",
        "//submodules/LegacyComponents",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/ComponentFlow",
        "//submodules/TelegramPresentationData",
        "//submodules/ContextUI",
        "//submodules/TooltipUI",
        "//submodules/UndoUI",
        "//submodules/TelegramUI/Components/ChatEntityKeyboardInputNode",
        "//submodules/TelegramUI/Components/MessageInputPanelComponent",
        "//submodules/TelegramNotices",
        "//submodules/TextFormat",
        "//submodules/TelegramUIPreferences",
        "//submodules/Pasteboard",
        "//submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "LegacyMessageInputPanelTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":LegacyMessageInputPanel",
        "//submodules/Display",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15.
ios_test_runner(
    name = "LegacyMessageInputPanelTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "LegacyMessageInputPanelTests",
    minimum_os_version = "15.0",
    runner = ":LegacyMessageInputPanelTestRunner",
    deps = [
        ":LegacyMessageInputPanelTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
