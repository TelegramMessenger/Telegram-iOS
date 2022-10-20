load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WebUI",
    module_name = "WebUI",
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
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/AccountContext:AccountContext",
        "//submodules/AttachmentUI:AttachmentUI",
        "//submodules/CounterContollerTitleView:CounterContollerTitleView",
        "//submodules/HexColor:HexColor",
        "//submodules/PhotoResources:PhotoResources",
        "//submodules/ShimmerEffect:ShimmerEffect",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/UrlHandling:UrlHandling",
        "//submodules/MoreButtonNode:MoreButtonNode",
        "//submodules/BotPaymentsUI:BotPaymentsUI",
        "//submodules/PromptUI:PromptUI",
        "//submodules/PhoneNumberFormat:PhoneNumberFormat",
    ],
    visibility = [
        "//visibility:public",
    ],
)
