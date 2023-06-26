load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EmptyStateIndicatorComponent",
    module_name = "EmptyStateIndicatorComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/Components/AnimatedStickerComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
