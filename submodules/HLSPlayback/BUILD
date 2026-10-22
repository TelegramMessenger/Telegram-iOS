load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_test")

swift_library(
    name = "HLSPlayback",
    module_name = "HLSPlayback",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)

# Host (macOS) test: the module needs nothing but Foundation.
# Run with `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/HLSPlayback:HLSPlaybackTests`.
swift_test(
    name = "HLSPlaybackTests",
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":HLSPlayback",
    ],
)
