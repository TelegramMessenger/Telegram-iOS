load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ShareItems",
    module_name = "ShareItems",
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
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/Display:Display",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/LocalMediaResources:LocalMediaResources",
        "//submodules/Pdf:Pdf",
        "//submodules/AccountContext:AccountContext",
    	"//submodules/ShareItems/Impl:ShareItemsImpl",
    ],
    visibility = [
        "//visibility:public",
    ],
)
