load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MessageInlineBlockBackgroundView",
    module_name = "MessageInlineBlockBackgroundView",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/Components/HierarchyTrackingLayer",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/TelegramUI/Components/AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
