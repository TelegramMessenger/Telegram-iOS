load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "TranslateUI",
    module_name = "TranslateUI",
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
        "//submodules/AccountContext:AccountContext",
        "//submodules/AlertUI:AlertUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/Speak:Speak",
        "//submodules/ManagedAnimationNode:ManagedAnimationNode",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",        
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Components/ViewControllerComponent:ViewControllerComponent",
        "//submodules/Components/MultilineTextComponent:MultilineTextComponent",
        "//submodules/Components/MultilineTextWithEntitiesComponent:MultilineTextWithEntitiesComponent",
        "//submodules/Components/BundleIconComponent:BundleIconComponent",
        "//submodules/UndoUI:UndoUI",
        "//submodules/ActivityIndicator:ActivityIndicator",
        "//submodules/ShimmerEffect:ShimmerEffect",
        "//submodules/Components/ResizableSheetComponent",
        "//submodules/TelegramUI/Components/GlassBarButtonComponent",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/ListActionItemComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TextFormat",
        "//submodules/Pasteboard",
        "//submodules/TelegramUI/Components/TranslationLanguagesContextMenuContent",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "TranslateUITestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":TranslateUI",
        "//submodules/TelegramCore:TelegramCore",
    ],
)

ios_test_runner(
    name = "TranslateUITestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "TranslateUITests",
    minimum_os_version = "15.0",
    runner = ":TranslateUITestRunner",
    deps = [
        ":TranslateUITestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
