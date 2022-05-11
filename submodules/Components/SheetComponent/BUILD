load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SheetComponent",
    module_name = "SheetComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Components/ViewControllerComponent:ViewControllerComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
