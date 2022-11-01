load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGStats",
    module_name = "NGStats",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/AccountContext:AccountContext",
        "//Nicegram/EsimModule/FileStorage:FileStorage",
        "//Nicegram/NGApiClient:NGApiClient",
        "//Nicegram/NGData:NGData",
        "//Nicegram/NGRemoteConfig:NGRemoteConfig",
        "//Nicegram/NGUtils:NGUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
