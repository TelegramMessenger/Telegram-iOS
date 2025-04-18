load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WatchBridgeAudio",
    module_name = "WatchBridgeAudio",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    	"//submodules/WatchBridgeAudio/Impl:WatchBridgeAudioImpl",
    ],
    visibility = [
        "//visibility:public",
    ],
)
