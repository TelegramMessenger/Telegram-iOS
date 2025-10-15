load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FaceScanScreen",
    module_name = "FaceScanScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/PresentationDataUtils",
        "//submodules/TextFormat",
        "//submodules/Markdown",
        "//submodules/Camera",
        "//submodules/FileMediaResourceStatus",
        "//submodules/TelegramUIPreferences",
        "//submodules/UndoUI",
        "//submodules/DeviceAccess",
        "//third-party/ZipArchive",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/Components/SheetComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
