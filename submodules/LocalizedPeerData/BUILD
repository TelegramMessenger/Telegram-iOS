load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LocalizedPeerData",
    module_name = "LocalizedPeerData",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SyncCore:SyncCore",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/PhoneNumberFormat:PhoneNumberFormat",
    ],
    visibility = [
        "//visibility:public",
    ],
)
