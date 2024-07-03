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
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
    	"//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/AppBundle",
        "//submodules/InstantPageUI",
        "//submodules/ContextUI",
        "//submodules/UndoUI",
        "//submodules/TranslateUI",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Components/ViewControllerComponent:ViewControllerComponent",
        "//submodules/Components/MultilineTextComponent:MultilineTextComponent",
        "//submodules/Components/BundleIconComponent:BundleIconComponent",
        "//submodules/Components/BlurredBackgroundComponent:BlurredBackgroundComponent",
        "//submodules/TelegramUI/Components/MinimizedContainer",
        "//submodules/Pasteboard",
        "//submodules/SaveToCameraRoll",
    ],
    visibility = [
        "//visibility:public",
    ],
)
