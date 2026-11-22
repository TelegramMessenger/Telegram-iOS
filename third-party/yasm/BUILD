load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")

filegroup(
    name = "yasm_sources",
    srcs = glob([
        "yasm-1.3.0/**/*"
    ]),
)

genrule(
    name = "yasm",
    srcs = [
        ":yasm_sources",
        "@cmake_tar_gz//file",
    ],
    cmd_bash =
"""
set -x
    core_count=$$(nproc 2>/dev/null || PATH="$$PATH:/usr/sbin" sysctl -n hw.logicalcpu 2>/dev/null || echo 4)
    BUILD_DIR="$(RULEDIR)/build"
    rm -rf "$$BUILD_DIR"
    mkdir -p "$$BUILD_DIR"

    CMAKE_DIR="$$(pwd)/$$BUILD_DIR/cmake"
    rm -rf "$$CMAKE_DIR"
    mkdir -p "$$CMAKE_DIR"
    tar -xf "$(location @cmake_tar_gz//file)" -C "$$CMAKE_DIR"

    # Find cmake: try system cmake first, then downloaded macOS cmake
    if command -v cmake >/dev/null 2>&1; then
        CMAKE_BIN="cmake"
    elif [ -d "$$CMAKE_DIR/cmake-4.1.2-macos-universal/CMake.app/Contents/bin" ]; then
        CMAKE_BIN="$$CMAKE_DIR/cmake-4.1.2-macos-universal/CMake.app/Contents/bin/cmake"
    else
        echo "cmake not found"
        exit 1
    fi

    SOURCE_PATH="third-party/yasm/yasm-1.3.0"
    cp -R "$$SOURCE_PATH" "$$BUILD_DIR/"

    pushd "$$BUILD_DIR/yasm-1.3.0"
    mkdir build
    cd build
    "$$CMAKE_BIN" .. -DYASM_BUILD_TESTS=OFF -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DPYTHON_EXECUTABLE="$$(which python3)"
    make -j $$core_count
    popd

    tar -cf "$(location yasm.tar)" -C "$$BUILD_DIR/yasm-1.3.0/build" .
""",
    outs = [
        "yasm.tar",
    ],
    visibility = [
        "//visibility:public",
    ]
)
