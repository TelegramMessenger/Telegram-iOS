load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGTranslate",
    module_name = "NGTranslate",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//Nicegram/NGLogging:NGLogging",
        "//Nicegram/NGData:NGData"
    ],
    visibility = [
        "//visibility:public",
    ],
)
