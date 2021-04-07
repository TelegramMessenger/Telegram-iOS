
objc_library(
    name = "NotificationServiceObjC",
    enable_modules = True,
    module_name = "NotificationServiceObjC",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.h",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//submodules/BuildConfig:BuildConfig",
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/NotificationsPresentationData:NotificationsPresentationData",
        "//submodules/OpenSSLEncryptionProvider:OpenSSLEncryptionProvider",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    weak_sdk_frameworks = [
        "BackgroundTasks",
    ],
    visibility = [
        "//visibility:public",
    ],
)
