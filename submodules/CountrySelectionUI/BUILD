load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CountrySelectionUI",
    module_name = "CountrySelectionUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/SearchBarNode:SearchBarNode",
        "//submodules/AppBundle:AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
