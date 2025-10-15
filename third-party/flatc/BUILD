
genrule(
    name = "flatc",
    srcs = [
        "@flatbuffers_zip//file",
        "@cmake_tar_gz//file",
    ],
    cmd_bash =
"""
set -x
    core_count=`PATH="$$PATH:/usr/sbin" sysctl -n hw.logicalcpu`
    BUILD_DIR="$(RULEDIR)/build"
    rm -rf "$$BUILD_DIR"
    mkdir -p "$$BUILD_DIR"

    CMAKE_DIR="$$(pwd)/$$BUILD_DIR/cmake"
    rm -rf "$$CMAKE_DIR"
    mkdir -p "$$CMAKE_DIR"
    tar -xf "$(location @cmake_tar_gz//file)" -C "$$CMAKE_DIR"
    
    tar -xzf "$(location @flatbuffers_zip//file)" --directory "$$BUILD_DIR"
    pushd "$$BUILD_DIR/flatbuffers-24.12.23"
    mkdir build
    cd build
    PATH="$$PATH:$$CMAKE_DIR/cmake-3.23.1-macos-universal/CMake.app/Contents/bin" cmake .. -DCMAKE_BUILD_TYPE=Release -DFLATBUFFERS_BUILD_TESTS=0 -DFLATBUFFERS_INSTALL=0 -DFLATBUFFERS_BUILD_FLATLIB=0 -DFLATBUFFERS_STATIC_FLATC=0
    make -j $$core_count
    popd

    cp "$$BUILD_DIR/flatbuffers-24.12.23/build/flatc" "$(location flatc_bin)"
""",
    outs = [
        "flatc_bin",
    ],
    visibility = [
        "//visibility:public",
    ]
)
