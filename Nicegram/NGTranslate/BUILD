load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGTranslate",
    module_name = "NGTranslate",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/AccountContext:AccountContext",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//Nicegram/EsimModule/FileStorage:FileStorage",
        "//Nicegram/NGLogging:NGLogging",
        "//Nicegram/NGData:NGData",
        "//Nicegram/NGExtensions:NGExtensions",
        "//Nicegram/NGLocalization:NGLocalization",
        "//Nicegram/NGModels:NGModels",
        "//Nicegram/NGStrings:NGStrings",
    ],
    visibility = [
        "//visibility:public",
    ],
)
