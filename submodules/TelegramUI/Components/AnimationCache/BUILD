load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AnimationCache",
    module_name = "AnimationCache",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/CryptoUtils:CryptoUtils",
        "//submodules/ManagedFile:ManagedFile",
        "//submodules/TelegramUI/Components/AnimationCache/ImageDCT:ImageDCT",
    ],
    visibility = [
        "//visibility:public",
    ],
)
