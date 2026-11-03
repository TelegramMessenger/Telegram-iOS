cc_library(
    name = "fuzz_main",
    srcs = ["fuzz_main.c"],
)

cc_binary(
    name = "fuzz_iccprofile_atf",
    srcs = ["fuzz_iccprofile_atf.c"],
    deps = [
        ":fuzz_main",
        "//:skcms",
    ],
)

cc_binary(
    name = "fuzz_iccprofile_info",
    srcs = ["fuzz_iccprofile_info.c"],
    deps = [
        ":fuzz_main",
        "//:skcms",
    ],
)

cc_binary(
    name = "fuzz_iccprofile_transform",
    srcs = ["fuzz_iccprofile_transform.c"],
    deps = [
        ":fuzz_main",
        "//:skcms",
    ],
)
