load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_test")

swift_library(
    name = "SupportTemplates",
    module_name = "SupportTemplates",
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
# Run with `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TelegramUI/Components/Support/SupportTemplates:SupportTemplatesTests`.
swift_test(
    name = "SupportTemplatesTests",
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":SupportTemplates",
    ],
)
