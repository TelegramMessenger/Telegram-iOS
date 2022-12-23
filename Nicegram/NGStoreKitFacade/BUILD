load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGStoreKitFacade",
    module_name = "NGStoreKitFacade",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
		"//Vendor/SwiftyStoreKit:SwiftyStoreKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
