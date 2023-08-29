load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "VolumeButtons",
    module_name = "VolumeButtons",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/LegacyComponents",
    ],
    visibility = [
        "//visibility:public",
    ],
)
