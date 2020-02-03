load(
    "@rules_apple_extras//apple:objc_library.bzl",
    "my_swift_library",
)

my_swift_library(
    name = "WalletCore",
    module_name = "WalletCore",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
	    "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TonBinding:TonBinding",
    ],
    visibility = [
        "//visibility:public",
    ],
)
