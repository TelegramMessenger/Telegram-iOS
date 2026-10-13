load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "PeerInfoPaneNode",
    module_name = "PeerInfoPaneNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "PeerInfoPaneNodeTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":PeerInfoPaneNode",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
    ],
)

ios_test_runner(
    name = "PeerInfoPaneNodeTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "PeerInfoPaneNodeTests",
    minimum_os_version = "15.0",
    runner = ":PeerInfoPaneNodeTestRunner",
    deps = [
        ":PeerInfoPaneNodeTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
