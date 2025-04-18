load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LanguageSuggestionUI",
    module_name = "LanguageSuggestionUI",
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
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ActivityIndicator:ActivityIndicator",
    ],
    visibility = [
        "//visibility:public",
    ],
)
