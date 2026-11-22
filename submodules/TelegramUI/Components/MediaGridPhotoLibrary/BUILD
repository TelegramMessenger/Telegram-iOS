load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MediaGridPhotoLibrary",
    module_name = "MediaGridPhotoLibrary",
    srcs = glob(["Sources/**/*.swift"]),
    deps = [
        "//submodules/TelegramUI/Components/MediaGrid:MediaGrid",
    ],
    visibility = [
        "//visibility:public",
    ],
)
