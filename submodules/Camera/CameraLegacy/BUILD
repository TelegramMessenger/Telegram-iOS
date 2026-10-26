load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CameraLegacy",
    module_name = "CameraLegacy",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        "//submodules/Camera:CameraBundle",
    ],
    deps = [
        "//submodules/Camera",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/ImageBlur:ImageBlur",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Utils/DeviceModel",
        "//submodules/LottieBinding:LottieBinding",
        "//submodules/LottieSettings:LottieSettings",
        "//submodules/AppBundle",
        "//submodules/GZip",
    ],
    visibility = [
        "//visibility:public",
    ],
)
