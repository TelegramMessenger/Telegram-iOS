load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AudioTranscriptionPendingIndicatorComponent",
    module_name = "AudioTranscriptionPendingIndicatorComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/AppBundle:AppBundle",
        "//submodules/Display:Display",
        "//submodules/Components/LottieAnimationComponent:LottieAnimationComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
