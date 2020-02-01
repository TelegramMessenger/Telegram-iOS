load(
    "@rules_apple_extras//apple:objc_library.bzl",
    "objc_library",
)

load(
    "@bazel_skylib//rules:common_settings.bzl",
    "string_flag",
)

string_flag(
    name = "apiId",
    build_setting_default = "",
    visibility = ["//visibility:public"],
)

objc_library(
    name = "BuildConfig",
    module_name = "BuildConfig",
    enable_modules = True,
    srcs = glob([
        "Sources/*.m",
    ]),
    copts = [
        '-DAPP_CONFIG_API_ID=0',
        '-DAPP_CONFIG_API_HASH="1"',
        '-DAPP_CONFIG_HOCKEYAPP_ID="1"',
        '-DAPP_CONFIG_IS_INTERNAL_BUILD=false',
        '-DAPP_CONFIG_IS_APPSTORE_BUILD=true',
        '-DAPP_CONFIG_APPSTORE_ID=0',
        '-DAPP_SPECIFIC_URL_SCHEME="1"',
    ],
    hdrs = glob([
        "Sources/*.h",
    ]),
    deps = [
    ],
    visibility = ["//visibility:public"],
)
