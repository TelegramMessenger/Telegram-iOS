load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NavigationStackComponent",
    module_name = "NavigationStackComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/AppBundle",
        "//submodules/Components/BundleIconComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
