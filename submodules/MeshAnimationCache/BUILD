load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MeshAnimationCache",
    module_name = "MeshAnimationCache",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/LottieMeshSwift:LottieMeshSwift",
        "//submodules/Postbox:Postbox",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/GZip:GZip",
        "//submodules/AppBundle:AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
