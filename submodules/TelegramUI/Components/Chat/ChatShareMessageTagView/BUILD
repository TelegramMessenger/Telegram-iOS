load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatShareMessageTagView",
    module_name = "ChatShareMessageTagView",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/UndoUI",
        "//submodules/ContextUI",
        "//submodules/ReactionSelectionNode",
        "//submodules/TelegramUI/Components/EntityKeyboard",
    ],
    visibility = [
        "//visibility:public",
    ],
)
