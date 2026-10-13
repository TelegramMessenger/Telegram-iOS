load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "WalletContext",
    module_name = "WalletContext",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
        "-enable-testing",
    ],
    deps = [
      "//third-party/wallet-engine:WalletEngineFFI",
      "//submodules/SSignalKit/SwiftSignalKit",
      "//submodules/TelegramCore",
      "//submodules/TelegramUIPreferences",
      "//submodules/WalletBackupCrypto",
      "//submodules/PasscodeCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "WalletCardStickersTestsLib",
    testonly = True,
    srcs = ["Tests/WalletCardStickersTests.swift"],
    deps = [":WalletContext", "//submodules/TelegramCore"],
)

ios_test_runner(
    name = "WalletCardStickersTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "WalletCardStickersTests",
    minimum_os_version = "15.0",
    runner = ":WalletCardStickersTestRunner",
    deps = [":WalletCardStickersTestsLib"],
)
