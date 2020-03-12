
genrule(
    name = "yasm",
    srcs = [
        "yasm-1.3.0.tar.gz",
    ],
    cmd_bash =
"""
set -x
    core_count="`sysctl -n hw.logicalcpu`"
    BUILD_DIR="$(RULEDIR)/build"
    rm -rf "$$BUILD_DIR"
    mkdir -p "$$BUILD_DIR"

    CMAKE_DIR="$$(pwd)/$$BUILD_DIR/cmake"
    rm -rf "$$CMAKE_DIR"
    mkdir -p "$$CMAKE_DIR"
    tar -xf "$(location //third-party/cmake:cmake.tar)" -C "$$CMAKE_DIR"
    
    tar -xzf "$(location yasm-1.3.0.tar.gz)" --directory "$$BUILD_DIR"
    pushd "$$BUILD_DIR/yasm-1.3.0"
    mkdir build
    cd build
    PATH="$$PATH:$$CMAKE_DIR/bin" cmake .. -DYASM_BUILD_TESTS=OFF -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
    make -j $$core_count
    popd

    tar -cf "$(location yasm.tar)" -C "$$BUILD_DIR/yasm-1.3.0/build" .
""",
    tools = [
        "//third-party/cmake:cmake.tar",
    ],
    outs = [
        "yasm.tar",
    ],
    visibility = [
        "//visibility:public",
    ]
)
