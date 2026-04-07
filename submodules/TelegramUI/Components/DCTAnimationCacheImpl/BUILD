load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "DCTAnimationCacheImpl",
    module_name = "DCTAnimationCacheImpl",
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
        "//submodules/TelegramUI/Components/AnimationCache:AnimationCache",
        "//submodules/TelegramUI/Components/AnimationCache/ImageDCT:ImageDCT",
        "//third-party/subcodec:SubcodecObjC",
    ],
    visibility = [
        "//visibility:public",
    ],
)
