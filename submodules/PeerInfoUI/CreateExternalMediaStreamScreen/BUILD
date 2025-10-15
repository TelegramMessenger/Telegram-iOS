load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CreateExternalMediaStreamScreen",
    module_name = "CreateExternalMediaStreamScreen",
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
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Components/ViewControllerComponent:ViewControllerComponent",
        "//submodules/Components/MultilineTextComponent:MultilineTextComponent",
        "//submodules/Components/SolidRoundedButtonComponent:SolidRoundedButtonComponent",
        "//submodules/Components/BundleIconComponent:BundleIconComponent",
        "//submodules/Components/AnimatedStickerComponent:AnimatedStickerComponent",
        "//submodules/Components/ActivityIndicatorComponent:ActivityIndicatorComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
