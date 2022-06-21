load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ItemListAddressItem",
    module_name = "ItemListAddressItem",
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
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TextFormat:TextFormat",
        "//submodules/AppBundle:AppBundle",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
