load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGSpecialOffer",
    module_name = "NGSpecialOffer",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Vendor/SnapKit:SnapKit",
        "//submodules/lottie-ios:Lottie",
        "//Nicegram/EsimModule/EsimPropertyWrappers:EsimPropertyWrappers",
        "//Nicegram/EsimModule/EsimUI:EsimUI",
        "//Nicegram/NGButton:NGButton",
        "//Nicegram/NGCustomViews:NGCustomViews",
        "//Nicegram/NGData:NGData",
        "//Nicegram/NGLogging:NGLogging",
        "//Nicegram/NGRemoteConfig:NGRemoteConfig",
        "//Nicegram/NGTheme:NGTheme",
    ],
    visibility = ["//visibility:public"],

)
