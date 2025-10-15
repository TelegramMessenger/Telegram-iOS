load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "GroupStickerPackSetupController",
    module_name = "GroupStickerPackSetupController",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/AccountContext:AccountContext",
        "//submodules/StickerPackPreviewUI:StickerPackPreviewUI",
        "//submodules/ItemListStickerPackItem:ItemListStickerPackItem",
        "//submodules/SearchBarNode:SearchBarNode",
        "//submodules/SearchUI:SearchUI",
        "//submodules/MergeLists:MergeLists",
        "//submodules/UndoUI:UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
