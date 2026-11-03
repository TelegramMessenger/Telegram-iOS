load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "StringPluralization",
    module_name = "StringPluralization",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/NumberPluralizationForm:NumberPluralizationForm",
        "//submodules/AppBundle:AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
