load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WidgetItemsUtils",
    module_name = "WidgetItemsUtils",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
    	"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    	"//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
    	"//submodules/WidgetItems:WidgetItems",
    ],
    visibility = [
        "//visibility:public",
    ],
)
