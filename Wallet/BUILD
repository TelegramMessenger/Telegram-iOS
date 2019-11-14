load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

version_info_plist_source = """
echo \
'<?xml version="1.0" encoding="UTF-8"?>' \
'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
'<plist version="1.0">' \
'<dict>' \
'    <key>CFBundleShortVersionString</key>' \
'    <string>%s</string>' \
'    <key>CFBundleVersion</key>' \
'    <string>%s</string>' \
'</dict>' \
'</plist>' \
> "$@"
""" % ("1.0", "30")

genrule(
    name = "VersionInfoPlist",
    outs = ["VersionInfo.plist"],
    cmd = version_info_plist_source,
)

objc_library(
    name = "Main",
    srcs = [
        "Sources/main.m"
    ],
)

swift_library(
    name = "Lib",
    srcs = glob([
        "SupportFiles/**/*.swift",
    ]),
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
    ],
)

ios_application(
    name = "Wallet",
    bundle_id = "org.telegram-iOS.Wallet",
    families = ["iphone", "ipad"],
    minimum_os_version = "9.0",
    infoplists = [
        ":Info.plist",
        ":VersionInfoPlist",
    ],
    deps = [
        ":Main",
        ":Lib",
    ],
)
