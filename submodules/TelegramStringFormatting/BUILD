load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TelegramStringFormatting",
    module_name = "TelegramStringFormatting",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Display:Display",
        "//submodules/PlatformRestrictionMatching:PlatformRestrictionMatching",
        "//submodules/LocalizedPeerData:LocalizedPeerData",
        "//submodules/TextFormat:TextFormat",
        "//submodules/Markdown:Markdown",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AppBundle:AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
