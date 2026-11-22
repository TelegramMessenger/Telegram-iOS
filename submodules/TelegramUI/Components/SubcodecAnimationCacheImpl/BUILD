load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SubcodecAnimationCacheImpl",
    module_name = "SubcodecAnimationCacheImpl",
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
        "//third-party/subcodec:SubcodecObjC",
    ],
    visibility = [
        "//visibility:public",
    ],
)
