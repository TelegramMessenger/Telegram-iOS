load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ManagedAnimationNode",
    module_name = "ManagedAnimationNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/GZip:GZip",
        "//submodules/rlottie:RLottieBinding",
        "//submodules/AppBundle:AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
