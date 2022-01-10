load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NotificationServiceExtensionLib",
    module_name = "NotificationServiceExtensionLib",
    srcs = glob([
        "Sources/*.swift",
    ]),
    deps = [
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/BuildConfig:BuildConfig",
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/EncryptionProvider:EncryptionProvider",
        "//submodules/AppLockState:AppLockState",
        "//submodules/NotificationsPresentationData:NotificationsPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/OpenSSLEncryptionProvider:OpenSSLEncryptionProvider",
        "//submodules/WebPBinding:WebPBinding",
        "//submodules/rlottie:RLottieBinding",
        "//submodules/GZip:GZip",
        "//submodules/PersistentStringHash:PersistentStringHash",
    
    ],
    visibility = [
        "//visibility:public",
    ],
)
