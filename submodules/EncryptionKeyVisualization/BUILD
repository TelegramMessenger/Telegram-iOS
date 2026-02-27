load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EncryptionKeyVisualization",
    module_name = "EncryptionKeyVisualization",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
    	"//submodules/EncryptionKeyVisualization/Impl:EncryptionKeyVisualizationImpl",
    ],
    visibility = [
        "//visibility:public",
    ],
)
