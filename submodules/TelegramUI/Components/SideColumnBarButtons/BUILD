load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SideColumnBarButtons",
    module_name = "SideColumnBarButtons",
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
        "//submodules/TelegramPresentationData",
        "//submodules/AppBundle",
        "//submodules/ActivityIndicator",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/NavigationBarImpl",
        "//submodules/TelegramUI/Components/SideColumnLayout",
    ],
    visibility = [
        "//visibility:public",
    ],
)
