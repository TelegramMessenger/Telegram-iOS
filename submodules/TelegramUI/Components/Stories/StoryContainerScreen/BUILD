load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "StoryContainerScreen",
    module_name = "StoryContainerScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/TelegramUI/Components/MessageInputPanelComponent",
        "//submodules/AccountContext",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AppBundle",
        "//submodules/TelegramCore",
        "//submodules/ShareController",
        "//submodules/UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
