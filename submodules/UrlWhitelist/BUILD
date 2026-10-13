load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_test")

swift_library(
    name = "UrlWhitelist",
    module_name = "UrlWhitelist",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/UrlEscaping",
    ],
    visibility = [
        "//visibility:public",
    ],
)

# Host (macOS) test: the module needs nothing but Foundation and UrlEscaping.
# Run with `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/UrlWhitelist:UrlWhitelistTests`.
swift_test(
    name = "UrlWhitelistTests",
    srcs = [
        "Tests/UrlWhitelistTests.swift",
    ],
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":UrlWhitelist",
    ],
)
