load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "DirectMediaImageCache",
    module_name = "DirectMediaImageCache",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TinyThumbnail:TinyThumbnail",
        "//submodules/Display:Display",
        "//submodules/FastBlur:FastBlur",
        "//submodules/MozjpegBinding:MozjpegBinding",
        "//submodules/ManagedFile:ManagedFile",
    ],
    visibility = [
        "//visibility:public",
    ],
)
