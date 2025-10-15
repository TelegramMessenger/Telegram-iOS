load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AvatarUploadToastScreen",
    module_name = "AvatarUploadToastScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/AccountContext",
        "//submodules/RadialStatusNode",
        "//submodules/TelegramUI/Components/AnimatedTextComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
