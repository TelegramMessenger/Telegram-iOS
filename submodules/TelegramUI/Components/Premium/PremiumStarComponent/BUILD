load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PremiumStarComponent",
    module_name = "PremiumStarComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/ComponentFlow",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/GZip",
        "//submodules/LegacyComponents",
        "//submodules/AvatarNode",
        "//submodules/PhotoResources",
        "//submodules/TelegramUI/Components/Chat/MergedAvatarsNode",
        "//submodules/Components/MultilineTextComponent:MultilineTextComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
