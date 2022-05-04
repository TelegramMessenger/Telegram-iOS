load(
    "@build_bazel_rules_apple//apple:apple.bzl",
    "apple_dynamic_xcframework_import"
)

apple_dynamic_xcframework_import(
    name = "ecommpaySDK",
    xcframework_imports = glob([
        "ecommpaySDK.xcframework/**",
    ]),
    visibility = ["//visibility:public"],
)