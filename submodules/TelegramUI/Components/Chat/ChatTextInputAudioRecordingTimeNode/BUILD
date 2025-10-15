load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatTextInputAudioRecordingTimeNode",
    module_name = "ChatTextInputAudioRecordingTimeNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/ChatPresentationInterfaceState",
    ],
    visibility = [
        "//visibility:public",
    ],
)
