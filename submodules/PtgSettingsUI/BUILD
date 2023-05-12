load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PtgSettingsUI",
    module_name = "PtgSettingsUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AccountUtils:AccountUtils",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
