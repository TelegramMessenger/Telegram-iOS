load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LottieMetal",
    module_name = "LottieMetal",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/AnimatedStickerNode",
        "//submodules/GZip",
        "//submodules/MetalEngine",
        "//submodules/TelegramUI/Components/LottieCpp",
    ],
    visibility = [
        "//visibility:public",
    ],
)
