load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LanguageSelectionScreen",
    module_name = "LanguageSelectionScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/MergeLists",
        "//submodules/ItemListUI",
        "//submodules/PresentationDataUtils",
        "//submodules/AccountContext",
        "//submodules/SearchBarNode",
        "//submodules/SearchUI",
        "//submodules/TelegramUIPreferences",
        "//submodules/TranslateUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
