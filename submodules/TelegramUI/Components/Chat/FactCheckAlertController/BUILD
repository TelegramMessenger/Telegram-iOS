load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FactCheckAlertController",
    module_name = "FactCheckAlertController",
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
        "//submodules/ComponentFlow",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/TelegramUI/Components/TextFieldComponent",
        "//submodules/TextFormat",
    ],
    visibility = [
        "//visibility:public",
    ],
)
