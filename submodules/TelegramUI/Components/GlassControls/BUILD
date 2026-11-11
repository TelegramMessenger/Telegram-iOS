load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "GlassControls",
    module_name = "GlassControls",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramUI/Components/LottieComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
