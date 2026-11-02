load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application", "ios_unit_test")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

swift_library(
    name = "Display",
    module_name = "Display",
    srcs = glob([
        "Source/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
    	"//submodules/ObjCRuntimeUtils:ObjCRuntimeUtils",
    	"//submodules/UIKitRuntimeUtils:UIKitRuntimeUtils",
        "//submodules/AppBundle:AppBundle",
    	"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Markdown:Markdown",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "DisplayTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ], exclude = [
        "Tests/AccessibilityCollectorTests.swift",
        "Tests/CollectionIndexAccessibilityTests.swift",
        "Tests/TextLinkAccessibilityTests.swift",
        "Tests/WindowTouchReleaseStateTests.swift",
    ]),
    deps = [
        ":Display",
    ],
)

# The ASDK accessibility collector (`_ASDisplayViewAccessiblity.mm`) driven through Display's nodes and ListView, and
# the other tests that need a running app (`WindowTouchReleaseStateTests`: a recognizer's state machine).
swift_library(
    name = "DisplayAccessibilityTestsLib",
    testonly = True,
    srcs = [
        "Tests/AccessibilityCollectorTests.swift",
        "Tests/CollectionIndexAccessibilityTests.swift",
        "Tests/TextLinkAccessibilityTests.swift",
        "Tests/AccessibilityTextLinksTests.swift",
        "Tests/WindowTouchReleaseStateTests.swift",
    ],
    deps = [
        ":Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15.
ios_test_runner(
    name = "DisplayTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "DisplayTests",
    minimum_os_version = "15.0",
    runner = ":DisplayTestRunner",
    deps = [
        ":DisplayTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)

# DisplayAccessibilityTests need a running UIApplication (ListViewImpl's CADisplayLink is nil without one). The host
# links Display and AsyncDisplayKit itself so the test bundle does not carry a second copy: ASDK's `+load` creating a
# UIView while XCTest injects the bundle deadlocks in `+[UIScreen initialize]`.
swift_library(
    name = "DisplayAccessibilityTestHostLib",
    testonly = True,
    srcs = [
        "TestHost/AccessibilityTestHost.swift",
    ],
    deps = [
        ":Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    ],
)

plist_fragment(
    name = "DisplayAccessibilityTestHostInfoPlist",
    extension = "plist",
    template = """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.DisplayAccessibilityTestHost</string>
    <key>CFBundleName</key>
    <string>DisplayAccessibilityTestHost</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>UILaunchScreen</key>
    <dict/>
    """
)

ios_application(
    name = "DisplayAccessibilityTestHost",
    testonly = True,
    bundle_id = "org.telegram.DisplayAccessibilityTestHost",
    families = ["iphone"],
    minimum_os_version = "15.0",
    infoplists = [":DisplayAccessibilityTestHostInfoPlist"],
    deps = [
        "//Tests/Common:Main",
        ":DisplayAccessibilityTestHostLib",
    ],
)

# The reused test simulator would otherwise keep the previous host build (and with it the previous Display/ASDK).
sh_binary(
    name = "UninstallDisplayAccessibilityTestHost",
    srcs = ["TestHost/uninstall_test_host.sh"],
)

ios_test_runner(
    name = "DisplayAccessibilityTestRunner",
    pre_action = ":UninstallDisplayAccessibilityTestHost",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "DisplayAccessibilityTests",
    minimum_os_version = "15.0",
    # One reused simulator ("BAZEL_TEST_<device>_<os>") instead of a fresh one per run.
    env = {"REUSE_GLOBAL_SIMULATOR": "1"},
    runner = ":DisplayAccessibilityTestRunner",
    test_host = ":DisplayAccessibilityTestHost",
    deps = [
        ":DisplayAccessibilityTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
