load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "RichTextEditorMediaView",
    module_name = "RichTextEditorMediaView",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AccountContext",
        "//submodules/AppBundle:AppBundle",
        "//submodules/TelegramCore",
        "//submodules/InstantPageUI",
        "//submodules/InvisibleInkDustNode",
        "//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorCore",
        "//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorUIKit",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Display:Display",
        "//submodules/PhotoResources:PhotoResources",
        "//submodules/MediaResources:MediaResources",
        "//submodules/MosaicLayout:MosaicLayout",
        "//submodules/RadialStatusNode:RadialStatusNode",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "RichTextEditorMediaViewTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":RichTextEditorMediaView",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15.
ios_test_runner(
    name = "RichTextEditorMediaViewTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "RichTextEditorMediaViewTests",
    minimum_os_version = "15.0",
    runner = ":RichTextEditorMediaViewTestRunner",
    deps = [
        ":RichTextEditorMediaViewTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
