load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
    "apple_resource_group",
)
load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

filegroup(
    name = "CameraScreenMetalResources",
    srcs = glob([
        "MetalResources/**/*.*",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "CameraScreenBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.CameraScreen</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>CameraScreen</string>
    """
)

apple_resource_bundle(
    name = "CameraScreenBundle",
    infoplists = [
        ":CameraScreenBundleInfoPlist",
    ],
    resources = [
        ":CameraScreenMetalResources",
    ],
)

swift_library(
    name = "CameraScreen",
    module_name = "CameraScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":CameraScreenBundle",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/TelegramStringFormatting",
        "//submodules/PresentationDataUtils",
        "//submodules/LocalMediaResources",
        "//submodules/Camera",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BlurredBackgroundComponent",
        "//submodules/Components/LottieAnimationComponent:LottieAnimationComponent",
        "//submodules/Components/BundleIconComponent:BundleIconComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/TooltipUI",
        "//submodules/TelegramUI/Components/MediaEditor",
        "//submodules/Components/MetalImageView",
        "//submodules/TelegramUI/Components/CameraButtonComponent",
        "//submodules/Utils/VolumeButtons",
        "//submodules/TelegramNotices",
        "//submodules/DeviceAccess",
        
    ],
    visibility = [
        "//visibility:public",
    ],
)
