load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_test")

# Package.swift next to this file is the macOS (SwiftPM) build of the same sources.

swift_library(
    name = "MTProtoRustEngineMapping",
    module_name = "MTProtoRustEngineMapping",
    srcs = glob(["Sources/MTProtoRustEngineMapping/**/*.swift"]),
    copts = [
        "-warnings-as-errors",
    ],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "MTProtoRustEngine",
    module_name = "MTProtoRustEngine",
    srcs = glob(["Sources/MTProtoRustEngine/**/*.swift"]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":MTProtoRustEngineMapping",
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/WebProxyTransport:WebProxyTransport",
        "//third-party/mtproto-engine:MTProtoEngineFFI",
    ],
    visibility = ["//visibility:public"],
)

# Host (macOS) test: the mapping module is pure Foundation. The bridge and end-to-end tests stay
# SwiftPM-only (`swift test`), because they need the macOS MTProtoEngineFFI.xcframework.
swift_test(
    name = "MTProtoRustEngineMappingTests",
    srcs = glob(["Tests/MTProtoRustEngineMappingTests/**/*.swift"]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [":MTProtoRustEngineMapping"],
)
