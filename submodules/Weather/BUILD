load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Weather",
    module_name = "Weather",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AccountContext:AccountContext",
        "//submodules/DeviceAccess",
        "//submodules/DeviceLocationManager",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
