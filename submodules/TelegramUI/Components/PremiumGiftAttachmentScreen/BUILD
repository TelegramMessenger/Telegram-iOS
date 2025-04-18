load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PremiumGiftAttachmentScreen",
    module_name = "PremiumGiftAttachmentScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AccountContext",
        "//submodules/AttachmentUI",
        "//submodules/TelegramUI/Components/Gifts/GiftOptionsScreen",
    ],
    visibility = [
        "//visibility:public",
    ],
)
