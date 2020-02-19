load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application", "ios_framework")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

version_info_plist_source = """
echo \
'<?xml version="1.0" encoding="UTF-8"?>' \
'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
'<plist version="1.0">' \
'<dict>' \
'    <key>CFBundleShortVersionString</key>' \
'    <string>{}</string>' \
'    <key>CFBundleVersion</key>' \
'    <string>{}</string>' \
'</dict>' \
'</plist>' \
> "$@"
""".format("1.0", "30")

genrule(
    name = "VersionInfoPlist",
    outs = ["VersionInfo.plist"],
    cmd = version_info_plist_source,
)

filegroup(
    name = "Strings",
    srcs = glob([
        "Strings/**/*",
    ], exclude = ["Strings/**/.*"]),
)

objc_library(
    name = "Main",
    srcs = [
        "Sources/main.m"
    ],
)

ios_framework(
  name = "AsyncDisplayKitFramework",
  deps = ["//submodules/AsyncDisplayKit:AsyncDisplayKit"],
  bundle_id = "org.telegram.Telegram.AsyncDisplayKit",
  families = ["iphone", "ipad"],
  minimum_os_version = "9.0",
  infoplists = [
    "Info.plist"
  ],
)

swift_library(
    name = "Lib",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    data = [
        ":Strings",
    ],
    deps = [
        "//submodules/GZip:GZip",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/SSignalKit/SSignalKit:SSignalKit",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/ObjCRuntimeUtils:ObjCRuntimeUtils",
        "//submodules/UIKitRuntimeUtils:UIKitRuntimeUtils",
        "//submodules/Display:Display",
        "//submodules/AlertUI:AlertUI",
        "//submodules/ActivityIndicator:ActivityIndicator",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/openssl:openssl",
        "//submodules/OpenSSLEncryptionProvider:OpenSSLEncryptionProvider",
        "//submodules/WalletCore:WalletCore",
        "//submodules/BuildConfig:BuildConfig",
        "//submodules/AppBundle:AppBundle",
        "//submodules/SolidRoundedButtonNode:SolidRoundedButtonNode",
        "//submodules/Camera:Camera",
        "//submodules/QrCode:QrCode",
        "//submodules/MergeLists:MergeLists",
        "//submodules/GlassButtonNode:GlassButtonNode",
        "//submodules/UrlEscaping:UrlEscaping",
        "//submodules/LocalAuth:LocalAuth",
        "//submodules/ScreenCaptureDetection:ScreenCaptureDetection",
        "//submodules/WalletUrl:WalletUrl",
        "//submodules/ProgressNavigationButtonNode:ProgressNavigationButtonNode",
        "//submodules/Markdown:Markdown",
        "//submodules/StringPluralization:StringPluralization",
        "//submodules/YuvConversion:YuvConversion",
        "//submodules/rlottie:RLottieBinding",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/WalletUI:WalletUI",
    ],
)

ios_application(
    name = "Wallet",
    bundle_id = "{wallet_bundle_id}",
    families = ["iphone", "ipad"],
    minimum_os_version = "9.0",
    provisioning_profile = "Wallet.mobileprovision",
    infoplists = [
        ":Info.plist",
        ":VersionInfoPlist",
    ],
    frameworks = [
        ":AsyncDisplayKitFramework",
    ],
    deps = [
        ":Main",
        ":Lib",
    ],
)
