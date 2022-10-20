load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

UIDEPS = [
    "//submodules/ItemListPeerActionItem:ItemListPeerActionItem",
    "//submodules/ItemListUI:ItemListUI",
    "//submodules/PresentationDataUtils:PresentationDataUtils",
]

swift_library(
    name = "NGQuickReplies",
    module_name = "NGQuickReplies",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = UIDEPS + [
        "//submodules/AccountContext:AccountContext",
        "//Nicegram/EsimModule/FileStorage:FileStorage",
        "//Nicegram/NGStrings:NGStrings",
    ],
    visibility = ["//visibility:public"],

)
