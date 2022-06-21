load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LottieAnimationComponent",
    module_name = "LottieAnimationComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/lottie-ios:Lottie",
        "//submodules/AppBundle:AppBundle",
        "//submodules/Components/HierarchyTrackingLayer:HierarchyTrackingLayer",
    ],
    visibility = [
        "//visibility:public",
    ],
)
