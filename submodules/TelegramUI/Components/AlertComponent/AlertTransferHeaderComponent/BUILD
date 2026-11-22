load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AlertTransferHeaderComponent",
    module_name = "AlertTransferHeaderComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramPresentationData",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramUI/Components/AlertComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
