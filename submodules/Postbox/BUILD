load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "Postbox",
    module_name = "Postbox",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Crc32:Crc32",
    	"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    	"//submodules/sqlcipher:sqlcipher",
        "//submodules/MurMurHash32:MurMurHash32",
        "//submodules/StringTransliteration:StringTransliteration",
        "//submodules/ManagedFile:ManagedFile",
        "//submodules/Utils/RangeSet:RangeSet",
        "//submodules/CryptoUtils",
        "//submodules/Utils/DarwinDirStat",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "PostboxTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":Postbox",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/sqlcipher:sqlcipher",
    ],
)

ios_test_runner(
    name = "PostboxTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "PostboxTests",
    minimum_os_version = "15.0",
    runner = ":PostboxTestRunner",
    deps = [
        ":PostboxTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
