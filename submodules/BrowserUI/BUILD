load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "BrowserUI",
    module_name = "BrowserUI",
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
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/AppBundle:AppBundle",
        "//submodules/InstantPageUI:InstantPageUI",
        "//submodules/ContextUI:ContextUI",
        "//submodules/UndoUI:UndoUI",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Components/ViewControllerComponent:ViewControllerComponent",
        "//submodules/Components/MultilineTextComponent:MultilineTextComponent",
        "//submodules/Components/BundleIconComponent:BundleIconComponent",
        "//submodules/Components/BlurredBackgroundComponent:BlurredBackgroundComponent",
        "//submodules/TelegramUI/Components/MinimizedContainer",
    ],
    visibility = [
        "//visibility:public",
    ],
)
