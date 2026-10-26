load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WalletCollectibleImageComponent",
    module_name = "WalletCollectibleImageComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AccountContext",
        "//submodules/AsyncDisplayKit",
        "//submodules/ComponentFlow",
        "//submodules/Display",
        "//submodules/PhotoResources",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
