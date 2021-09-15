load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "UrlHandling",
    module_name = "UrlHandling",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/TelegramNotices:TelegramNotices",
    ],
    visibility = [
        "//visibility:public",
    ],
)
