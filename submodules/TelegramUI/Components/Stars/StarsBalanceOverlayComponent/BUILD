load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "StarsBalanceOverlayComponent",
    module_name = "StarsBalanceOverlayComponent",
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
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/MultilineTextWithEntitiesComponent",
        "//submodules/TelegramPresentationData",
        "//submodules/TextFormat",
        "//submodules/Markdown",
        "//submodules/TelegramStringFormatting",
    ],
    visibility = [
        "//visibility:public",
    ],
)
