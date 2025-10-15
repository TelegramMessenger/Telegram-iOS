
arch_specific_crc32c_sources = select({
    "@build_bazel_rules_apple//apple:ios_arm64": [
        "third_party/crc32c/src/crc32c_arm64.cc",
    ],
    "//build-system:ios_sim_arm64": [
        "third_party/crc32c/src/crc32c_arm64.cc",
    ],
})

crc32c_sources = ["third_party/crc32c/src/" + x for x in [
    "crc32c_portable.cc",
    "crc32c.cc",
    "crc32c_arm64.h",
    "crc32c_internal.h",
    "crc32c_prefetch.h",
    "crc32c_read_le.h",
    "crc32c_round_up.h",
    "crc32c_sse42.h",
    "crc32c_sse42_check.h",
    "crc32c_arm64_check.h",
]] + arch_specific_crc32c_sources

cc_library(
    name = "crc32c",
    hdrs = [
        "third_party/crc32c/src/include/crc32c/crc32c.h",
        "third_party/crc32c/src/include/crc32c/crc32c_config.h",
    ],
    srcs = crc32c_sources,
    copts = [
        "-Ithird-party/webrtc/crc32c/third_party/crc32c/src/include"
    ],
    cxxopts = [
        "-std=c++17",
    ],
    deps = [
    ],
    includes = [
        ".",
    ],
    visibility = ["//visibility:public"],
)
