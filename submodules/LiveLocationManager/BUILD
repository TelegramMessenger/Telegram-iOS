load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LiveLocationManager",
    module_name = "LiveLocationManager",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/DeviceLocationManager:DeviceLocationManager",
        "//submodules/AccountContext:AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
