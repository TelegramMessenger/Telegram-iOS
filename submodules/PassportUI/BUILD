load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PassportUI",
    module_name = "PassportUI",
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
        "//submodules/PhoneInputNode:PhoneInputNode",
        "//submodules/CountrySelectionUI:CountrySelectionUI",
        "//submodules/GalleryUI:GalleryUI",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/LegacyUI:LegacyUI",
        "//submodules/ImageCompression:ImageCompression",
        "//submodules/DateSelectionUI:DateSelectionUI",
        "//submodules/PasswordSetupUI:PasswordSetupUI",
        "//submodules/AppBundle:AppBundle",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/Markdown:Markdown",
        "//submodules/PhoneNumberFormat:PhoneNumberFormat",
    ],
    visibility = [
        "//visibility:public",
    ],
)
