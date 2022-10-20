load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AppLock",
    module_name = "AppLock",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/MonotonicTime:MonotonicTime",
        "//submodules/PasscodeUI:PasscodeUI",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/ImageBlur:ImageBlur",
        "//submodules/AccountContext:AccountContext",
        "//submodules/AppLockState:AppLockState",
    ],
    visibility = [
        "//visibility:public",
    ],
)
