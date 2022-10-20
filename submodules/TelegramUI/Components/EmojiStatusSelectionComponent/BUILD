load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EmojiStatusSelectionComponent",
    module_name = "EmojiStatusSelectionComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/TelegramUI/Components/AnimationCache:AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer:MultiAnimationRenderer",
        "//submodules/TelegramUI/Components/EntityKeyboard:EntityKeyboard",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView:EmojiTextAttachmentView",
        "//submodules/TelegramUI/Components/EmojiStatusComponent:EmojiStatusComponent",
        "//submodules/Components/ComponentDisplayAdapters:ComponentDisplayAdapters",
        "//submodules/Components/PagerComponent:PagerComponent",
        "//submodules/Components/MultilineTextComponent:MultilineTextComponent",
        "//submodules/Components/SolidRoundedButtonComponent:SolidRoundedButtonComponent",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/lottie-ios:Lottie",
        "//submodules/TextFormat:TextFormat",
        "//submodules/AppBundle:AppBundle",
        "//submodules/GZip:GZip",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
