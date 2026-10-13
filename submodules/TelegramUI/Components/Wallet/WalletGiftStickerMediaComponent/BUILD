load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
swift_library(
    name = "WalletGiftStickerMediaComponent",
    module_name = "WalletGiftStickerMediaComponent",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/AccountContext", "//submodules/LottieBinding",
        "//submodules/SSignalKit/SwiftSignalKit", "//submodules/TelegramCore", "//submodules/WalletContext",
        "//submodules/TelegramUI/Components/Wallet/WalletCollectibleHeaderComponent",
    ],
    visibility = ["//visibility:public"],
)
exports_files(["Sources/WalletGiftStickerCutout.swift"], visibility = ["//submodules/TelegramUI/Components/Wallet/WalletScreen:__pkg__"])
