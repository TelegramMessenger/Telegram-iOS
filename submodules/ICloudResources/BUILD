load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ICloudResources",
    module_name = "ICloudResources",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Display",
        "//submodules/Pdf",
    ],
    visibility = [
        "//visibility:public",
    ],
)
