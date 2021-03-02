load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NotificationServiceExtensionLib",
    module_name = "NotificationServiceExtensionLib",
    srcs = glob([
        "Sources/*.swift",
    ]),
    deps = [
        "//submodules/BuildConfig:BuildConfig",
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/EncryptionProvider:EncryptionProvider",
        "//submodules/AppLockState:AppLockState",
        "//submodules/NotificationsPresentationData:NotificationsPresentationData",
        "//Telegram/NotificationService/NotificationServiceObjC:NotificationServiceObjC",
    ],
    visibility = [
        "//visibility:public",
    ],
)
