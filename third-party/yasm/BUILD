
genrule(
    name = "yasm",
    srcs = [
        "yasm-1.3.0.tar.gz",
    ],
    cmd_bash =
"""
    core_count="`sysctl -n hw.logicalcpu`"
    BUILD_DIR="$(RULEDIR)/build"
    rm -rf "$$BUILD_DIR"
    mkdir -p "$$BUILD_DIR"
    CMAKE_DIR="$$BUILD_DIR/cmake"
    mkdir -p "$$CMAKE_DIR"
    cp "$(location //third-party/cmake:cmake.bin)" "$$CMAKE_DIR/cmake"
    tar -xzf "$(location yasm-1.3.0.tar.gz)" --directory "$$BUILD_DIR"
    pushd "$$BUILD_DIR/yasm-1.3.0"
    mkdir build
    cd build
    export PATH=\"$$PATH:$$CMAKE_DIR\"
    cmake .. -DYASM_BUILD_TESTS=OFF -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
    make -j $$core_count
    popd

    tar -cf "$(location yasm.tar)" -C "$$BUILD_DIR/yasm-1.3.0/build" .
""",
    tools = [
        "//third-party/cmake:cmake.bin",
    ],
    outs = [
        "yasm.tar",
    ],
    visibility = [
        "//visibility:public",
    ]
)
