
objc_library(
    name = "ShareItemsImpl",
    enable_modules = True,
    module_name = "ShareItemsImpl",
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
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/PhoneNumberFormat:PhoneNumberFormat",
        "//submodules/MimeTypes:MimeTypes",
    ],
    sdk_frameworks = [
        "Foundation",
        "UIKit",
        "MobileCoreServices",
        "AddressBook",
        "AVFoundation",
    ],
    weak_sdk_frameworks = [
        "PassKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
