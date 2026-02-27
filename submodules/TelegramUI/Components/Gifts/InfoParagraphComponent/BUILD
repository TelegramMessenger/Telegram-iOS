load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "InfoParagraphComponent",
    module_name = "InfoParagraphComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/Markdown",
        "//submodules/TextFormat",
    ],
    visibility = [
        "//visibility:public",
    ],
)
