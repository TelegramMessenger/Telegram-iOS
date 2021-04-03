load("@build_bazel_rules_apple//apple:resources.bzl", "apple_bundle_import")

apple_bundle_import(
    name = "NGSettingsBundle",
    bundle_imports = glob([
        "Settings.bundle/*",
        "Settings.bundle/**/*",
    ]),
    visibility = ["//visibility:public"]
)