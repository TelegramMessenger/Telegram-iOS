load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TopMessageReactions",
    module_name = "TopMessageReactions",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/AccountContext",
        "//submodules/ReactionSelectionNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
