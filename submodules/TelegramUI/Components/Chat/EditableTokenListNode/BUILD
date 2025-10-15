load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EditableTokenListNode",
    module_name = "EditableTokenListNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/AvatarNode",
        "//submodules/AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
