load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Postbox",
    module_name = "Postbox",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/Crc32:Crc32",
    	"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    	"//submodules/sqlcipher:sqlcipher",
        "//submodules/MurMurHash32:MurMurHash32",
        "//submodules/StringTransliteration:StringTransliteration",
    ],
    visibility = [
        "//visibility:public",
    ],
)
