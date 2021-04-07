load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "DatePickerNode",
    module_name = "DatePickerNode",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/SegmentedControlNode:SegmentedControlNode",
        "//submodules/DirectionalPanGesture:DirectionalPanGesture",
    ],
    visibility = [
        "//visibility:public",
    ],
)
