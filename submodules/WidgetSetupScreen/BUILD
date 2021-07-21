load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WidgetSetupScreen",
    module_name = "WidgetSetupScreen",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/Display:Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/ItemListPeerItem:ItemListPeerItem",
        "//submodules/ItemListPeerActionItem:ItemListPeerActionItem",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/AccountContext:AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
