
objc_library(
    name = "WatchBridgeImpl",
    enable_modules = True,
    module_name = "WatchBridgeImpl",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.h",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/WatchCommon/Host:WatchCommon",
    ],
    sdk_frameworks = [
        "Foundation",
        "WatchConnectivity",
    ],
    visibility = [
        "//visibility:public",
    ],
)
