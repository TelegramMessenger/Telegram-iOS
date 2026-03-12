load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TranslationLanguagesContextMenuContent",
    module_name = "TranslationLanguagesContextMenuContent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/LocalizedPeerData",
        "//submodules/TelegramStringFormatting",
        "//submodules/TextFormat",
        "//submodules/ContextUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
