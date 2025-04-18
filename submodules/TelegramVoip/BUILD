load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TelegramVoip",
    module_name = "TelegramVoip",
    srcs = glob([
        "Sources/**/*.swift",
    ], exclude = [
        "Sources/macOS/**/*",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/TgVoipWebrtc:TgVoipWebrtc",
        "//submodules/FFMpegBinding",
        "//submodules/ManagedFile",
        "//submodules/AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
