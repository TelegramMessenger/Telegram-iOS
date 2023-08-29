load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatScheduleTimeController",
    module_name = "ChatScheduleTimeController",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/AccountContext",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramStringFormatting",
        "//submodules/SolidRoundedButtonNode",
        "//submodules/PresentationDataUtils",
        "//submodules/UIKitRuntimeUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
