load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WalletCollectibleItemComponent",
    module_name = "WalletCollectibleItemComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/WalletContext",
        "//submodules/TelegramUI/Components/Wallet/WalletCollectibleImageComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
