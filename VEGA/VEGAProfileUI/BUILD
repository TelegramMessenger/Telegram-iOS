load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "VEGAProfileUI",
    module_name = "VEGAProfileUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
    ],
    deps = [
	"//VEGA/lyra-ios-profile/LyraProfile",
        "//VEGA/lyra-ios-core-ui/LyraCoreUIWidget",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/AccountContext:AccountContext",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/ContextUI:ContextUI",
        "//submodules/TelegramBaseController:TelegramBaseController"
    ],
    visibility = [
        "//visibility:public",
    ],
)
