load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NavigationBarImpl",
    module_name = "NavigationBarImpl",
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
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/EdgeEffect",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
