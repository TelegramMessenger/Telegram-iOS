load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NotificationMuteSettingsUI",
    module_name = "NotificationMuteSettingsUI",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
    	"//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SyncCore:SyncCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
    ],
    visibility = [
        "//visibility:public",
    ],
)
