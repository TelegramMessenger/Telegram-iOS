load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SemanticStatusNode",
    module_name = "SemanticStatusNode",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/GZip:GZip",
        "//submodules/rlottie:RLottieBinding",
        "//submodules/AppBundle:AppBundle",
        "//submodules/ManagedAnimationNode:ManagedAnimationNode"
    ],
    visibility = [
        "//visibility:public",
    ],
)
