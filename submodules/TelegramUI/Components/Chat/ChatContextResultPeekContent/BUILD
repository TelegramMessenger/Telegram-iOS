load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatContextResultPeekContent",
    module_name = "ChatContextResultPeekContent",
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
        "//submodules/PhotoResources",
        "//submodules/AppBundle",
        "//submodules/ContextUI",
        "//submodules/SoftwareVideo",
        "//submodules/TelegramUI/Components/BatchVideoRendering",
        "//submodules/TelegramUI/Components/GifVideoLayer",
    ],
    visibility = [
        "//visibility:public",
    ],
)
