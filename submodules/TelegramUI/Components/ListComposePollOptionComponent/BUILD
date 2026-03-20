load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ListComposePollOptionComponent",
    module_name = "ListComposePollOptionComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/ComponentFlow",
        "//submodules/TelegramCore",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramUI/Components/SliderComponent",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/TextFieldComponent",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView",
        "//submodules/Components/BundleIconComponent",
        "//submodules/CheckNode",
        "//submodules/AccountContext",
        "//submodules/TextFormat",
        "//submodules/PresentationDataUtils",
        "//submodules/PhotoResources",
        "//submodules/LocationResources",
        "//submodules/RadialStatusNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
