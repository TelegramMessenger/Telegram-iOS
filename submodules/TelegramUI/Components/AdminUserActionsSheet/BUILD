load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AdminUserActionsSheet",
    module_name = "AdminUserActionsSheet",
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
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/PresentationDataUtils",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/AvatarNode",
        "//submodules/CheckNode",
        "//submodules/UndoUI",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/ListActionItemComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
