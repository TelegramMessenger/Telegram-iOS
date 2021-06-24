load("@build_bazel_rules_apple//apple:apple.bzl",
    "apple_static_framework_import",
)

apple_static_framework_import(
    name = "AppCenter",
    framework_imports = glob(["AppCenter-SDK-Apple/iOS/AppCenter.framework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_framework_import(
    name = "AppCenterCrashes",
    framework_imports = glob(["AppCenter-SDK-Apple/iOS/AppCenterCrashes.framework/**"]),
    visibility = ["//visibility:public"],
)
