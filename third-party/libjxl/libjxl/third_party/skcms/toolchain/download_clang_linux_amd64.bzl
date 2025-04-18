"""
This file assembles a toolchain for an amd64 Linux host using the Clang Compiler and glibc.

It downloads the necessary headers, executables, and pre-compiled static/shared libraries to
the external subfolder of the Bazel cache (the same place third party deps are downloaded with
http_archive or similar functions in WORKSPACE.bazel). These will be able to be used via our
custom c++ toolchain configuration (see //toolchain/linux_amd64_toolchain_config.bzl)

Most files are downloaded as .deb files from packages.debian.org (with us acting as the dependency
resolver) and extracted to
  [outputRoot (aka Bazel cache)]/[outputUserRoot]/[outputBase]/external/clang_linux_amd64
  (See https://bazel.build/docs/output_directories#layout-diagram)
which will act as our sysroot.
"""

load("//toolchain:utils.bzl", "gcs_mirror_url")

# From https://github.com/llvm/llvm-project/releases/download/llvmorg-13.0.0/clang+llvm-13.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz.sha256
clang_prefix = "clang+llvm-13.0.0-x86_64-linux-gnu-ubuntu-20.04/"
clang_sha256 = "2c2fb857af97f41a5032e9ecadf7f78d3eff389a5cd3c9ec620d24f134ceb3c8"
clang_url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-13.0.0/clang+llvm-13.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz"

debs_to_install = [
    # These three comprise glibc. libc6 has the shared libraries, like libc itself, the math library
    # (libm), etc. linux-libc-dev has the header files specific to linux. libc6-dev has the libc
    # system headers (e.g. malloc.h, math.h).
    {
        # From https://packages.debian.org/bullseye/amd64/libc6/download
        "sha256": "a6263062b476cee1052972621d473b159debec6e424f661eda88248b00331d79",
        "url": "https://ftp.debian.org/debian/pool/main/g/glibc/libc6_2.31-13+deb11u4_amd64.deb",
    },
    {
        # From https://packages.debian.org/bullseye/amd64/linux-libc-dev/download
        "sha256": "e89023a5fc58c30ebb8cbb82de77f872baeafe7a5449f574b03cea478f7e9e6d",
        "url": "https://ftp.debian.org/debian/pool/main/l/linux/linux-libc-dev_5.10.140-1_amd64.deb",
    },
    {
        # From https://packages.debian.org/bullseye/amd64/libc6-dev/download
        "sha256": "5f368eb89d102ccd23529a02fb17aaa1c15e7612506e22ef0c559b71f5049a91",
        "url": "https://ftp.debian.org/debian/pool/main/g/glibc/libc6-dev_2.31-13+deb11u4_amd64.deb",
    },
]

def _download_and_extract_deb(ctx, deb, sha256, prefix, output = ""):
    """Downloads a debian file and extracts the data into the provided output directory"""

    # https://bazel.build/rules/lib/repository_ctx#download_and_extract
    # A .deb file has a data.tar.xz and a control.tar.xz, but the important contents
    # (i.e. the headers or libs) are in the data.tar.xz
    ctx.download_and_extract(
        url = gcs_mirror_url(deb, sha256),
        output = "tmp",
        sha256 = sha256,
    )

    # https://bazel.build/rules/lib/repository_ctx#extract
    ctx.extract(
        archive = "tmp/data.tar.xz",
        output = output,
        stripPrefix = prefix,
    )

    # Clean up
    ctx.delete("tmp")

def _download_clang_linux_amd64_impl(ctx):
    # Download the clang toolchain (the extraction can take a while)
    # https://bazel.build/rules/lib/repository_ctx#download_and_extract
    ctx.download_and_extract(
        url = gcs_mirror_url(clang_url, clang_sha256),
        output = "",
        stripPrefix = clang_prefix,
        sha256 = clang_sha256,
    )

    # Extract all the debs into our sysroot. This is very similar to installing them, except their
    # dependencies are not installed automatically.
    for deb in debs_to_install:
        _download_and_extract_deb(
            ctx,
            deb["url"],
            deb["sha256"],
            ".",
        )

    # Create a BUILD.bazel file that makes the files downloaded into the toolchain visible.
    # We have separate groups for each task because doing less work (sandboxing fewer files
    # or uploading less data to RBE) makes compiles go faster. We try to strike a balance
    # between minimal specifications and not having to edit this file often with our use
    # of globs.
    # https://bazel.build/rules/lib/repository_ctx#file
    ctx.file(
        "BUILD.bazel",
        content = """
# DO NOT EDIT THIS BAZEL FILE DIRECTLY
# Generated from ctx.file action in download_linux_amd64_toolchain.bzl
filegroup(
    name = "archive_files",
    srcs = [
        "bin/llvm-ar",
    ],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "compile_files",
    srcs = [
        "bin/clang",
    ] + glob(
        include = [
            "include/c++/v1/**",
            "usr/include/**",
            "lib/clang/13.0.0/include/**",
            "usr/include/x86_64-linux-gnu/**",
        ],
        allow_empty = False,
    ),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "link_files",
    srcs = [
        "bin/clang",
        "bin/ld.lld",
        "bin/lld",
        "lib/libc++.a",
        "lib/libc++abi.a",
        "lib/libunwind.a",
        "lib64/ld-linux-x86-64.so.2",
    ] + glob(
        include = [
            "lib/clang/13.0.0/lib/**",
            "lib/x86_64-linux-gnu/**",
            "usr/lib/x86_64-linux-gnu/**",
        ],
        allow_empty = False,
    ),
    visibility = ["//visibility:public"],
)
""",
        executable = False,
    )

# https://bazel.build/rules/repository_rules
download_clang_linux_amd64 = repository_rule(
    implementation = _download_clang_linux_amd64_impl,
    attrs = {},
    doc = "Downloads clang, and all supporting headers, executables, " +
          "and shared libraries required to build skcms on a Linux amd64 host",
)
