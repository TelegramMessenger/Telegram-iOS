load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PasscodeUI",
    module_name = "PasscodeUI",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/ContextUI",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/Wallet/WalletSendKeyboardComponent",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/PresentationDataUtils",
        "//submodules/TelegramUIPreferences",
        "//submodules/AccountContext",
        "//submodules/LocalAuth",
        "//submodules/LegacyComponents",
        "//submodules/TelegramStringFormatting",
        "//submodules/ImageBlur",
        "//submodules/AppBundle",
        "//submodules/PasscodeInputFieldNode",
        "//submodules/MonotonicTime",
        "//submodules/GradientBackground",
        "//submodules/PasscodeCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
