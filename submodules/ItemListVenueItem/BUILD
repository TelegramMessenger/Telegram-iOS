load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ItemListVenueItem",
    module_name = "ItemListVenueItem",
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
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/LocationResources:LocationResources",
        "//submodules/ShimmerEffect:ShimmerEffect",
    ],
    visibility = [
        "//visibility:public",
    ],
)
