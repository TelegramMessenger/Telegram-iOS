load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LiveLocationPositionNode",
    module_name = "LiveLocationPositionNode",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/AppBundle:AppBundle",
        "//submodules/LocationResources:LocationResources",
        "//submodules/AccountContext:AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
