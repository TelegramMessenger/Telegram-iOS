load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ScreenCaptureDetection",
    module_name = "ScreenCaptureDetection",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
    	"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
