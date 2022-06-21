load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LegacyUI",
    module_name = "LegacyUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
    	"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramAudio:TelegramAudio",
        "//submodules/DeviceAccess:DeviceAccess",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/StickerResources:StickerResources",
        "//submodules/AttachmentUI:AttachmentUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
