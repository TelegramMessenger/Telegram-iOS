load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@rules_cc//cc:objc_library.bzl", "objc_library")

objc_library(
    name = "LensTransitionRuntime",
    module_name = "LensTransitionRuntime",
    enable_modules = True,
    srcs = glob(["Bridge/Sources/*.m", "Bridge/Sources/*.inc"]),
    hdrs = glob(["Bridge/PublicHeaders/**/*.h"]),
    includes = ["Bridge/PublicHeaders"],
    sdk_frameworks = ["UIKit", "Foundation"],
)


swift_library(
    name = "LensTransition",
    module_name = "LensTransition",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":LensTransitionRuntime",
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
