load(
    "@build_bazel_rules_apple//apple:apple.bzl",
    "apple_dynamic_xcframework_import",
    "apple_static_xcframework_import",
    "apple_dynamic_framework_import",
)

apple_static_xcframework_import(
    name = "RecaptchaEnterprise",
    xcframework_imports = glob(["RecaptchaEnterprise.xcframework/**"]),
    features = [
    ],
    visibility = [
        "//visibility:public",
    ],
)
