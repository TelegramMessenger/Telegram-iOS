load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MapResourceToAvatarSizes",
    module_name = "MapResourceToAvatarSizes",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Display:Display",
    ],
    visibility = [
        "//visibility:public",
    ],
)
