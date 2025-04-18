load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SearchUI",
    module_name = "SearchUI",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/SearchBarNode:SearchBarNode",
        "//submodules/ChatListSearchItemNode:ChatListSearchItemNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
