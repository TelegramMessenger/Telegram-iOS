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
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/TelegramNotices:TelegramNotices",
        "//submodules/WalletContext:WalletContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
