load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LottieAnimationCache",
    module_name = "LottieAnimationCache",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramUI/Components/AnimationCache:AnimationCache",
        "//submodules/Display:Display",
        "//submodules/rlottie:RLottieBinding",
        "//submodules/GZip:GZip",
    ],
    visibility = [
        "//visibility:public",
    ],
)
