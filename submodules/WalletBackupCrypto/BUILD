
load("@rules_cc//cc:objc_library.bzl", "objc_library")

objc_library(
    name = "WalletBackupCrypto",
    module_name = "WalletBackupCrypto",
    enable_modules = True,
    srcs = glob(["Sources/**/*.mm"]),
    hdrs = glob(["PublicHeaders/**/*.h"]),
    includes = ["PublicHeaders"],
    copts = ["-Werror"],
    cxxopts = [
        "-Werror",
        "-std=c++17",
    ],
    deps = ["//third-party/td:td"],
    sdk_frameworks = [
        "Foundation",
        "Security",
    ],
    visibility = ["//visibility:public"],
)

