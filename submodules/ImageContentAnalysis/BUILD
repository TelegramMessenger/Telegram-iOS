load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ImageContentAnalysis",
    module_name = "ImageContentAnalysis",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        #"-warnings-as-errors",
    ],
    deps = [
    	"//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
    ],
    visibility = [
        "//visibility:public",
    ],
)
