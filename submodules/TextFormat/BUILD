load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TextFormat",
    module_name = "TextFormat",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
    	"//submodules/TelegramCore:TelegramCore",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/Markdown:Markdown",
        "//submodules/Emoji:Emoji",
        "//third-party/libprisma",
    ],
    visibility = [
        "//visibility:public",
    ],
)
