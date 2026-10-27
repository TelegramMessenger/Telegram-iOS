load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ImageInpainting",
    module_name = "ImageInpainting",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-O",
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AccountContext",
        "//submodules/FileMediaResourceStatus",
        "//third-party/ZipArchive:ZipArchive",
    ],
    visibility = [
        "//visibility:public",
    ],
)
