load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ItemListAvatarAndNameInfoItem",
    module_name = "ItemListAvatarAndNameInfoItem",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/PeerPresenceStatusManager:PeerPresenceStatusManager",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/ActivityIndicator:ActivityIndicator",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/AppBundle:AppBundle",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/PhoneNumberFormat:PhoneNumberFormat",
        "//submodules/AccountContext:AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
