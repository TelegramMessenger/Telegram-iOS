load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGSecretMenu",
    module_name = "NGSecretMenu",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
		"//submodules/PresentationDataUtils:PresentationDataUtils",
        "//Nicegram/NGRemoteConfig:NGRemoteConfig",
    ],
    visibility = [
        "//visibility:public",
    ],
)
