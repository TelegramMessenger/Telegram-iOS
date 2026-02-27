load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatInputMessageAccessoryPanel",
    module_name = "ChatInputMessageAccessoryPanel",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramPresentationData",
        "//submodules/ComponentFlow",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramUI/Components/Chat/ChatInputAccessoryPanel",
        "//submodules/Display",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/MultilineTextWithEntitiesComponent",
        "//submodules/TelegramStringFormatting",
        "//submodules/PhotoResources",
        "//submodules/TextFormat",
        "//submodules/TelegramUI/Components/CompositeTextNode",
        "//submodules/ChatInterfaceState",
    ],
    visibility = [
        "//visibility:public",
    ],
)
