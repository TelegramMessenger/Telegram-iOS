load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AnimatedAvatarSetNode",
    module_name = "AnimatedAvatarSetNode",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/Display:Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/AudioBlob:AudioBlob",
    ],
    visibility = [
        "//visibility:public",
    ],
)
