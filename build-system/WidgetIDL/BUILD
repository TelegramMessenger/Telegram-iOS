load("@build_bazel_rules_swift//swift:swift.bzl", "swift_binary", "swift_library", "swift_test")

# The WebIDL bindings generator of the message-widget native runtime (docs/message-widgets-native-runtime.md). A
# host tool: the
# WidgetRuntime genrules run it at build time; nothing it generates is checked in.
swift_library(
    name = "WidgetIDLCore",
    module_name = "WidgetIDLCore",
    srcs = glob(["Sources/WidgetIDLCore/*.swift"]),
    copts = ["-warnings-as-errors"],
)

swift_binary(
    name = "WidgetIDL",
    srcs = ["Sources/WidgetIDL/main.swift"],
    copts = ["-warnings-as-errors"],
    deps = [":WidgetIDLCore"],
    visibility = ["//submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:__pkg__"],
)

# ./build-input/bazel-9.2.0-darwin-arm64 test //build-system/WidgetIDL:WidgetIDLTests
swift_test(
    name = "WidgetIDLTests",
    srcs = glob(["Tests/WidgetIDLTests/*.swift"]),
    deps = [":WidgetIDLCore"],
)
