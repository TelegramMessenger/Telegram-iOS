load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatHistoryImportTasks",
    module_name = "ChatHistoryImportTasks",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
