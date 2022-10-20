load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "BotPaymentsUI",
    module_name = "BotPaymentsUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
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
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/ShimmerEffect:ShimmerEffect",
        "//submodules/CheckNode:CheckNode",
        "//submodules/TextFormat:TextFormat",
        "//submodules/Markdown:Markdown",
    ],
    visibility = [
        "//visibility:public",
    ],
)
