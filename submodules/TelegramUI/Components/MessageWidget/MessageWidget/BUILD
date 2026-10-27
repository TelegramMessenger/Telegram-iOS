load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "MessageWidget",
    module_name = "MessageWidget",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/TelegramUI/Components/MessageWidget/MessageWidgetRendering",
        "//submodules/TelegramUI/Components/MessageWidget/WidgetRuntimeIOS",
        # Intl's locale data: widget-sandbox's iOS glue answers the runtime's `intl` requests.
        "//third-party/widget-sandbox:WidgetSandboxIntl",
    ],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "MessageWidgetTestsLib",
    testonly = True,
    srcs = glob(["Tests/**/*.swift"]),
    deps = [
        ":MessageWidget",
        # InstanceTests reads the instance's renderer.
        "//submodules/TelegramUI/Components/MessageWidget/MessageWidgetRendering",
        # SnapshotTests feeds the tree renderer a session's trees.
        "//submodules/TelegramUI/Components/MessageWidget/WidgetRuntimeIOS",
    ],
)

ios_test_runner(
    name = "MessageWidgetTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "MessageWidgetTests",
    minimum_os_version = "15.0",
    runner = ":MessageWidgetTestRunner",
    resources = [
        "//submodules/TelegramUI/Components/MessageWidget/Fixtures:WidgetFixtures",
        # widget-sandbox's corpus by folder, at corpus/<folder>/ in the bundle (WidgetCorpus.swift).
        "//third-party/widget-sandbox:WidgetCorpus",
        # widget-sandbox's conformance set, at conformance/ in the bundle (ChannelTests).
        "//third-party/widget-sandbox:WidgetConformance",
    ],
    deps = [":MessageWidgetTestsLib"],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "MessageWidgetCorpusTestsLib",
    testonly = True,
    srcs = glob(["CorpusTests/*.swift"]) + ["Tests/TestSupport.swift", "Tests/WidgetCorpus.swift"],
    deps = [
        ":MessageWidget",
        "//submodules/TelegramUI/Components/MessageWidget/MessageWidgetRendering",
    ],
)

ios_unit_test(
    name = "MessageWidgetCorpusTests",
    minimum_os_version = "15.0",
    runner = ":MessageWidgetTestRunner",
    # The corpus check boots ~230 widgets with taps and timers: minutes, not the main suite's seconds.
    size = "large",
    resources = [
        "//submodules/TelegramUI/Components/MessageWidget/Fixtures:WidgetFixtures",
        "//third-party/widget-sandbox:WidgetCorpus",
    ],
    deps = [":MessageWidgetCorpusTestsLib"],
    visibility = ["//visibility:public"],
)
