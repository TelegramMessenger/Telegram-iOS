load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ResizableSheetComponent",
    module_name = "ResizableSheetComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Components/ViewControllerComponent:ViewControllerComponent",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramUI/Components/DynamicCornerRadiusView",
        "//submodules/TelegramUI/Components/EdgeEffect",
    ],
    visibility = [
        "//visibility:public",
    ],
)
