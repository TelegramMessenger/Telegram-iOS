load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "StickerResources",
    module_name = "StickerResources",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Postbox:Postbox",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/ImageBlur:ImageBlur",
        "//submodules/Tuples:Tuples",
        "//submodules/MediaResources:MediaResources",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/WebPBinding:WebPBinding",
    ],
    visibility = [
        "//visibility:public",
    ],
)
