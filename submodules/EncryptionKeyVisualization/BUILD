load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EncryptionKeyVisualization",
    module_name = "EncryptionKeyVisualization",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SyncCore:SyncCore",
    	"//submodules/EncryptionKeyVisualization/Impl:EncryptionKeyVisualizationImpl",
    ],
    visibility = [
        "//visibility:public",
    ],
)
