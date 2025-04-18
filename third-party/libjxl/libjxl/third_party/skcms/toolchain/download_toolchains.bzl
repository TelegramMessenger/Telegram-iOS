"""
This file exports the various toolchains for the hosts that we support building skcms on.

Supported:
 - Linux amd64 (targeting Linux amd64 and Android)

Planned:
 - Windows amd64
 - Mac M1 and Intel

"""

load(":download_clang_linux_amd64.bzl", "download_clang_linux_amd64")
load(":download_ndk_linux_amd64.bzl", "download_ndk_linux_amd64")

name_toolchain = {
    "clang_linux_amd64": download_clang_linux_amd64,
    "ndk_linux_amd64": download_ndk_linux_amd64,
}

def download_toolchains_for_skcms(*args):
    """
    Point Bazel to the correct rules for downloading the different toolchains.

    Args:
        *args: multiple toolchains, see top of file for
               list of supported toolchains.
    """

    for toolchain_name in args:
        if toolchain_name not in name_toolchain:
            fail("unrecognized toolchain name " + toolchain_name)
        download_toolchain = name_toolchain[toolchain_name]
        download_toolchain(name = toolchain_name)
