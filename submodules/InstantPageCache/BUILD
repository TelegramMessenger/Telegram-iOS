load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "InstantPageCache",
    module_name = "InstantPageCache",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/TelegramCore:TelegramCore#shared",
        "//submodules/SyncCore:SyncCore#shared",
        "//submodules/Postbox:Postbox#shared",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit#shared",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/PersistentStringHash:PersistentStringHash",
    ],
    visibility = [
        "//visibility:public",
    ],
)
