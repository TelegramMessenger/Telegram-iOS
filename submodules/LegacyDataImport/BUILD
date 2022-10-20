load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LegacyDataImport",
    module_name = "LegacyDataImport",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SyncCore:SyncCore",
        "//submodules/Postbox:Postbox",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramNotices:TelegramNotices",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/RadialStatusNode:RadialStatusNode",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/LegacyDataImport/Impl:LegacyDataImportImpl",
    ],
    visibility = [
        "//visibility:public",
    ],
)
