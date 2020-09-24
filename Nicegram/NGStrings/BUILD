load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGStrings",
    module_name = "NGStrings",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/NGLogging:NGLogging",
        "//submodules/AppBundle:AppBundle"
    ],
    visibility = [
        "//visibility:public",
    ],
)
