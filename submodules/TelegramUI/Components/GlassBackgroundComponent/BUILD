load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "GlassBackgroundComponent",
    module_name = "GlassBackgroundComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/UIKitRuntimeUtils",
        "//submodules/AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
