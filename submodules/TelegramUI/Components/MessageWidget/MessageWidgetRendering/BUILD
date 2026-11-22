load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# The widget's pixels on WidgetRuntime: WidgetTreeRenderer draws a session's published layer trees as tiles, and a
# frozen widget's badge (M1d plan, Task 8).
swift_library(
    name = "MessageWidgetRendering",
    module_name = "MessageWidgetRendering",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/TelegramUI/Components/MessageWidget/WidgetRuntimeIOS",
    ],
    visibility = ["//visibility:public"],
)
