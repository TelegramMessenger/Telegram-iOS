load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TextFieldComponent",
    module_name = "TextFieldComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TextFormat",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/InvisibleInkDustNode",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView",
        "//submodules/ChatTextLinkEditUI",
        "//submodules/Pasteboard",
        "//submodules/ImageTransparency",
    ],
    visibility = [
        "//visibility:public",
    ],
)
