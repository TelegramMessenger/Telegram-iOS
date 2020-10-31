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
        "//submodules/Database/ValueBox:ValueBox",
        "//submodules/Database/PostboxDataTypes:PostboxDataTypes",
        "//submodules/Database/MessageHistoryReadStateTable:MessageHistoryReadStateTable",
        "//submodules/Database/MessageHistoryMetadataTable:MessageHistoryMetadataTable",
        "//submodules/Database/PreferencesTable:PreferencesTable",
        "//submodules/Database/PeerTable:PeerTable",
        "//submodules/sqlcipher:sqlcipher",
        "//submodules/AppLockState:AppLockState",
        "//submodules/NotificationsPresentationData:NotificationsPresentationData",
        "//Telegram/NotificationService/NotificationServiceObjC:NotificationServiceObjC",
    ],
    visibility = [
        "//visibility:public",
    ],
)
