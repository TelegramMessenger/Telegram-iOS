load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "StorySetIndicatorComponent",
    module_name = "StorySetIndicatorComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramPresentationData",
        "//submodules/AvatarNode",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/PhotoResources",
        "//submodules/AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
