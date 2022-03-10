load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WallpaperBackgroundNode",
    module_name = "WallpaperBackgroundNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/GradientBackground:GradientBackground",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/WallpaperResources:WallpaperResources",
        "//submodules/FastBlur:FastBlur",
        "//submodules/Svg:Svg",
        "//submodules/GZip:GZip",
        "//submodules/AppBundle:AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
