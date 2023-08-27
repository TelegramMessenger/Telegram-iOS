load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")

'''http_archive(
    name = "com_google_protobuf",
    urls = ["https://github.com/protocolbuffers/protobuf/releases/download/v22.2/protobuf-22.2.zip"],
    sha256 = "bf1f92aebd619651220711e97b3d560cdc2484718cd56d95161bfb2fadb8628e",
    strip_prefix = "protobuf-22.2",
    type = "zip",
)

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")
protobuf_deps()'''

local_repository(
    name = "build_bazel_rules_apple",
    path = "build-system/bazel-rules/rules_apple",
)

local_repository(
    name = "build_bazel_rules_swift",
    path = "build-system/bazel-rules/rules_swift",
)

local_repository(
    name = "build_bazel_apple_support",
    path = "build-system/bazel-rules/apple_support",
)

local_repository(
    name = "rules_xcodeproj",
    path = "build-system/bazel-rules/rules_xcodeproj",
)

load(
    "@build_bazel_rules_apple//apple:repositories.bzl",
    "apple_rules_dependencies",
)

apple_rules_dependencies()

load(
    "@build_bazel_rules_swift//swift:repositories.bzl",
    "swift_rules_dependencies",
)

swift_rules_dependencies()

load(
    "@build_bazel_apple_support//lib:repositories.bzl",
    "apple_support_dependencies",
)

apple_support_dependencies()

load(
    "@rules_xcodeproj//xcodeproj:repositories.bzl",
    "xcodeproj_rules_dependencies",
)

xcodeproj_rules_dependencies()

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

http_file(
    name = "cmake_tar_gz",
    urls = ["https://github.com/Kitware/CMake/releases/download/v3.23.1/cmake-3.23.1-macos-universal.tar.gz"],
    sha256 = "f794ed92ccb4e9b6619a77328f313497d7decf8fb7e047ba35a348b838e0e1e2",
)

http_archive(
    name = "appcenter_sdk",
    urls = ["https://github.com/microsoft/appcenter-sdk-apple/releases/download/4.1.1/AppCenter-SDK-Apple-4.1.1.zip"],
    sha256 = "032907801dc7784744a1ca8fd40d3eecc34a2e27a93a4b3993f617cca204a9f3",
    build_file = "@//third-party/AppCenter:AppCenter.BUILD",
)

load("@build_bazel_rules_apple//apple:apple.bzl", "provisioning_profile_repository")

provisioning_profile_repository(
    name = "local_provisioning_profiles",
)
