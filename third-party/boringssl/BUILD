# Copyright (c) 2016, Google Inc.
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
# OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
# CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE. */

licenses(["notice"])

exports_files(["LICENSE"])

#load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")

load(
    ":BUILD.generated.bzl",
    "crypto_headers",
    "crypto_internal_headers",
    "crypto_sources",
    "crypto_sources_mac_x86_64",
    "crypto_sources_ios_aarch64",
    "crypto_sources_ios_arm",
    "fips_fragments",
    "ssl_headers",
    "ssl_internal_headers",
    "ssl_sources",
    "tool_sources",
    "tool_headers",
)

posix_copts = [
    # Assembler option --noexecstack adds .note.GNU-stack to each object to
    # ensure that binaries can be built with non-executable stack.
    "-Wa,--noexecstack",

    # This is needed on Linux systems (at least) to get rwlock in pthread.
    "-D_XOPEN_SOURCE=700",

    # This list of warnings should match those in the top-level CMakeLists.txt.
    "-Wall",
    "-Werror",
    "-Wformat=2",
    "-Wsign-compare",
    "-Wmissing-field-initializers",
    "-Wwrite-strings",
    "-Wshadow",
    "-fno-common",

    # Modern build environments should be able to set this to use atomic
    # operations for reference counting rather than locks. However, it's
    # known not to work on some Android builds.
    # "-DOPENSSL_C11_ATOMIC",
]

boringssl_copts = select({
    "@build_bazel_rules_apple//apple:ios_armv7": posix_copts,
    "@build_bazel_rules_apple//apple:ios_arm64": posix_copts,
    "//build-system:ios_sim_arm64": posix_copts,
    "@build_bazel_rules_apple//apple:ios_x86_64": posix_copts,
})

crypto_sources_asm = select({
    "@build_bazel_rules_apple//apple:ios_armv7": crypto_sources_ios_arm,
    "@build_bazel_rules_apple//apple:ios_arm64": crypto_sources_ios_aarch64,
    "//build-system:ios_sim_arm64": crypto_sources_ios_aarch64,
    "@build_bazel_rules_apple//apple:ios_x86_64": crypto_sources_mac_x86_64,
})

# For C targets only (not C++), compile with C11 support.
posix_copts_c11 = [
    "-std=c11",
    "-Wmissing-prototypes",
    "-Wold-style-definition",
    "-Wstrict-prototypes",
]

boringssl_copts_c11 = boringssl_copts + select({
    "@build_bazel_rules_apple//apple:ios_armv7": posix_copts_c11,
    "@build_bazel_rules_apple//apple:ios_arm64": posix_copts_c11,
    "//build-system:ios_sim_arm64": posix_copts_c11,
    "@build_bazel_rules_apple//apple:ios_x86_64": posix_copts_c11,
})

# For C++ targets only (not C), compile with C++11 support.
posix_copts_cxx = [
    "-std=c++11",
    "-Wmissing-declarations",
]

boringssl_copts_cxx = boringssl_copts + select({
    "@build_bazel_rules_apple//apple:ios_armv7": posix_copts_cxx,
    "@build_bazel_rules_apple//apple:ios_arm64": posix_copts_cxx,
    "//build-system:ios_sim_arm64": posix_copts_cxx,
    "@build_bazel_rules_apple//apple:ios_x86_64": posix_copts_cxx,
})

cc_library(
    name = "crypto",
    srcs = crypto_sources + crypto_internal_headers + crypto_sources_asm + ["aes_ige.c"],
    hdrs = crypto_headers + fips_fragments,
    copts = boringssl_copts_c11,
    includes = ["src/include"],
    linkopts = select({
        "@build_bazel_rules_apple//apple:ios_armv7": [],
        "@build_bazel_rules_apple//apple:ios_arm64": [],
        "//build-system:ios_sim_arm64": [],
        "@build_bazel_rules_apple//apple:ios_x86_64": [],
    }),
    linkstatic = 1,
    visibility = ["//visibility:public"],
)

filegroup(
    name='libcrypto',
    srcs=[':crypto'],
    #output_group = 'library',
    visibility = ["//visibility:public"],
)

cc_library(
    name = "ssl",
    srcs = ssl_sources + ssl_internal_headers,
    hdrs = ssl_headers,
    copts = boringssl_copts_cxx,
    includes = ["src/include"],
    visibility = ["//visibility:public"],
    deps = [
        ":crypto",
    ],
)
