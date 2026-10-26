load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "TelegramStringFormatting",
    module_name = "TelegramStringFormatting",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Display:Display",
        "//submodules/PlatformRestrictionMatching:PlatformRestrictionMatching",
        "//submodules/LocalizedPeerData:LocalizedPeerData",
        "//submodules/TextFormat:TextFormat",
        "//submodules/Markdown:Markdown",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AppBundle:AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "TelegramStringFormattingTestsLib",
    testonly = True,
    srcs = glob(["Tests/**/*.swift"]),
    deps = [
        ":TelegramStringFormatting",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Postbox:Postbox",
        "//submodules/TextFormat:TextFormat",
    ],
)

ios_test_runner(
    name = "TelegramStringFormattingTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "TelegramStringFormattingTests",
    minimum_os_version = "15.0",
    runner = ":TelegramStringFormattingTestRunner",
    deps = [":TelegramStringFormattingTestsLib"],
    visibility = ["//visibility:public"],
)
