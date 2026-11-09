load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TelegramUIPreferences",
    module_name = "TelegramUIPreferences",
    srcs = glob([
        "Sources/**/*.swift",
    ], exclude = [
        # These scaffolding files reference modules that are not dependencies of
        # TelegramUIPreferences (AsyncDisplayKit, Display, AccountContext,
        # TelegramPresentationData). Depending on them from here would create a
        # dependency cycle, so they stay in the tree but outside the build.
        "Sources/JokerGhostMode.swift",
        "Sources/JokerModIntegration.swift",
        "Sources/JokerAutoSaveMedia.swift",
        "Sources/JokerDeletedMessages.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
