load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGTelegramRepo",
    module_name = "NGTelegramRepo",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/AccountContext:AccountContext",
		"//Nicegram/NGCore:NGCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
