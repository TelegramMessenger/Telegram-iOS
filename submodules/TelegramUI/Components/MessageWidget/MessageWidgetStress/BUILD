load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# widget-sandbox v0.3.0's renderer stress kit (third-party/widget-sandbox/stress, CLIENTS.md): the runner a client writes
# around its own renderer, which loads each stress widget, measures its frames and the host's and renderer's work, and
# writes the run file the maintainers set the paint limits from. Development tooling: the widget harness
# (`-widget-stress`) and DEBUG builds' Debug Settings host it.
swift_library(
    name = "MessageWidgetStress",
    module_name = "MessageWidgetStress",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/TelegramUI/Components/MessageWidget/MessageWidget",
    ],
    visibility = ["//visibility:public"],
)
