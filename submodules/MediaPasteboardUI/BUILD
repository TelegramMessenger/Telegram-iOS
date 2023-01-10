load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MediaPasteboardUI",
    module_name = "MediaPasteboardUI",
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
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/AttachmentUI:AttachmentUI",
        "//submodules/MediaPickerUI:MediaPickerUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
