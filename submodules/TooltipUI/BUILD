load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TooltipUI",
    module_name = "TooltipUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AppBundle:AppBundle",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/SyncCore:SyncCore",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TextFormat:TextFormat",
        "//submodules/UrlEscaping:UrlEscaping",
    ],
    visibility = [
        "//visibility:public",
    ],
)
