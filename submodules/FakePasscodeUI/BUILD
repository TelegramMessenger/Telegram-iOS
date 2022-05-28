load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FakePasscodeUI",
    module_name = "FakePasscodeUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/FakePasscode:FakePasscode",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/PasscodeUI:PasscodeUI",
        "//submodules/PasscodeInputFieldNode:PasscodeInputFieldNode",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/LocalMediaResources:LocalMediaResources",
        "//submodules/ItemListPeerActionItem:ItemListPeerActionItem",
        "//submodules/AccountUtils:AccountUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
