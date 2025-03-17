load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "JoinSubjectScreen",
    module_name = "JoinSubjectScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
