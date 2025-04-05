load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "QuickShareScreen",
    module_name = "QuickShareScreen",
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
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/PresentationDataUtils",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/AvatarNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
