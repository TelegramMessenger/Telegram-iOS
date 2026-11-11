# The platform half of WidgetRuntime on iOS (M1d plan, Tasks 5–7): the CoreText and ImageIO RenderHost, the layer-tree
# painter over LHContainer's CoreGraphics code, and the WRSession facade Swift calls.
load("@rules_cc//cc:objc_library.bzl", "objc_library")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

objc_library(
    name = "WidgetRuntimeIOS",
    module_name = "WidgetRuntimeIOS",
    enable_modules = True,
    srcs = glob(["Sources/*.mm", "Sources/*.h"]),
    hdrs = glob(["PublicHeaders/**/*.h"], allow_empty = True),
    includes = ["PublicHeaders"],
    copts = ["-std=gnu++20"],
    sdk_frameworks = [
        "Foundation",
        "CoreGraphics",
        "CoreText",
        "ImageIO",
        "QuartzCore",
        "Security",
    ],
    deps = [
        "//submodules/TelegramUI/Components/MessageWidget/WidgetRuntime",
        "//third-party/twidget:LiteHTML",
    ],
    visibility = ["//visibility:public"],
)

# The sources the work-unit scan reads (WidgetRuntime:WidgetRuntimeNoWorkUnitsScanTests).
filegroup(
    name = "ScanSources",
    testonly = True,
    srcs = glob(["Sources/*.mm", "Sources/*.h"]),
    visibility = ["//submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:__pkg__"],
)

objc_library(
    name = "WidgetRuntimeIOSTestsLib",
    testonly = True,
    srcs = glob(["Tests/*.mm"]),
    copts = ["-std=gnu++20"],
    # widget-sandbox v0.1.1's Intl fixture, its mapping and the drift list, as the test bundle's resources.
    data = [
        "//third-party/widget-sandbox:IntlCases",
        "//submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:IntlCasesSupport",
    ],
    sdk_frameworks = ["XCTest"],
    deps = [":WidgetRuntimeIOS"],
)

# The Intl cases end to end (WRIntlCasesTests.swift): Swift, because its delegate answers through widget-sandbox's iOS
# glue as the app's does. Its resources are the library's above.
swift_library(
    name = "WidgetRuntimeIOSSwiftTestsLib",
    testonly = True,
    srcs = glob(["Tests/*.swift"]),
    deps = [
        ":WidgetRuntimeIOS",
        "//third-party/widget-sandbox:WidgetSandboxIntl",
    ],
)

ios_test_runner(
    name = "WidgetRuntimeIOSTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "WidgetRuntimeIOSTests",
    minimum_os_version = "15.0",
    runner = ":WidgetRuntimeIOSTestRunner",
    deps = [
        ":WidgetRuntimeIOSSwiftTestsLib",
        ":WidgetRuntimeIOSTestsLib",
    ],
)
