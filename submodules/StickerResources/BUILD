load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "StickerResources",
    module_name = "StickerResources",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/TelegramCore:TelegramCore#shared",
        "//submodules/SyncCore:SyncCore#shared",
        "//submodules/Postbox:Postbox#shared",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit#shared",
        "//submodules/Display:Display#shared",
        "//submodules/ImageBlur:ImageBlur",
        "//submodules/Tuples:Tuples",
        "//submodules/MediaResources:MediaResources",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/WebP:WebPImage",
    ],
    visibility = [
        "//visibility:public",
    ],
)
