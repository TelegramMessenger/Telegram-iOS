load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MultiVideoRenderer",
    module_name = "MultiVideoRenderer",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/SoftwareVideo:SoftwareVideo",
    ],
    visibility = [
        "//visibility:public",
    ],
)
