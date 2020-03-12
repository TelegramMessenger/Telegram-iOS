load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TelegramNotices",
    module_name = "TelegramNotices",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
    	"//submodules/Postbox:Postbox",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramPermissions:TelegramPermissions",
    ],
    visibility = [
        "//visibility:public",
    ],
)
