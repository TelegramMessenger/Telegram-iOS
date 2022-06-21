load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SearchBarNode",
    module_name = "SearchBarNode",
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
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ActivityIndicator:ActivityIndicator",
        "//submodules/AppBundle:AppBundle",
        "//submodules/ComponentFlow:ComponentFlow",
    ],
    visibility = [
        "//visibility:public",
    ],
)
