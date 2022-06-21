load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AvatarNode",
    module_name = "AvatarNode",
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
        "//submodules/AnimationUI:AnimationUI",
        "//submodules/AppBundle:AppBundle",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Emoji:Emoji",
        "//submodules/TinyThumbnail:TinyThumbnail",
        "//submodules/FastBlur:FastBlur",
    ],
    visibility = [
        "//visibility:public",
    ],
)
