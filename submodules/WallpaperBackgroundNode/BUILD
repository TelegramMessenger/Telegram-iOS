load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WallpaperBackgroundNode",
    module_name = "WallpaperBackgroundNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-O",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/GradientBackground:GradientBackground",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/SyncCore:SyncCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
