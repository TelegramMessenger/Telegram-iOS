load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CommunityEditScreen",
    module_name = "CommunityEditScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AccountContext",
        "//submodules/AvatarNode",
        "//submodules/ComponentFlow",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Display",
        "//submodules/MapResourceToAvatarSizes",
        "//submodules/PeerInfoUI",
        "//submodules/RadialStatusNode",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUI/Components/AlertComponent",
        "//submodules/TelegramUI/Components/AvatarEditorScreen",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramUI/Components/CameraScreen",
        "//submodules/TelegramUI/Components/ListActionItemComponent",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/ListTextFieldItemComponent",
        "//submodules/TelegramUI/Components/MediaEditor",
        "//submodules/TelegramUI/Components/MediaEditorScreen",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/TelegramUI/Components/Settings/PeerSelectionScreen",
        "//submodules/TelegramUI/Components/Stories/PeerListItemComponent",
        "//submodules/ItemListUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
