load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "BotPaymentsUI",
    module_name = "BotPaymentsUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SyncCore:SyncCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/LocalAuth:LocalAuth",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/PasswordSetupUI:PasswordSetupUI",
        "//submodules/PhotoResources:PhotoResources",
        "//submodules/TelegramNotices:TelegramNotices",
        "//submodules/Stripe:Stripe",
        "//submodules/CountrySelectionUI:CountrySelectionUI",
        "//submodules/AppBundle:AppBundle",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
