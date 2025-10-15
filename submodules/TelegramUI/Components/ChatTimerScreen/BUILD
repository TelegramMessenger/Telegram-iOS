load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatTimerScreen",
    module_name = "ChatTimerScreen",
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
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/SolidRoundedButtonNode:SolidRoundedButtonNode",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
    ],
    visibility = [
        "//visibility:public",
    ],
)
