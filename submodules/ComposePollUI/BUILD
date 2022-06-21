load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ComposePollUI",
    module_name = "ComposePollUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/AccountContext:AccountContext",
        "//submodules/AlertUI:AlertUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/TextFormat:TextFormat",
        "//submodules/ObjCRuntimeUtils:ObjCRuntimeUtils",
        "//submodules/AttachmentUI:AttachmentUI",
        "//submodules/TextInputMenu:TextInputMenu",
    ],
    visibility = [
        "//visibility:public",
    ],
)
