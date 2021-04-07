load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatListSearchItemNode",
    module_name = "ChatListSearchItemNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/SearchBarNode:SearchBarNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
