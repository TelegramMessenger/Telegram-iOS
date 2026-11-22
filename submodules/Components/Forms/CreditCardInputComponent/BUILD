load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CreditCardInputComponent",
    module_name = "CreditCardInputComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Stripe:Stripe",
    ],
    visibility = [
        "//visibility:public",
    ],
)
