
genrule(
    name = "cmake",
    srcs = [
        "cmake-3.16.0.tar.gz",
    ],
    cmd_bash =
"""
    BUILD_DIR="$(RULEDIR)/build"
    rm -rf "$$BUILD_DIR"
    mkdir -p "$$BUILD_DIR"
    tar -xzf "$(location cmake-3.16.0.tar.gz)" --directory "$$BUILD_DIR"
    
    pushd "$$BUILD_DIR/cmake-3.16.0"

    core_count="`sysctl -n hw.logicalcpu`"
    ./bootstrap --parallel=$$core_count -- -DCMAKE_BUILD_TYPE:STRING=Release
    make -j $$core_count

    popd

    cp "$$BUILD_DIR/cmake-3.16.0/bin/cmake" "$(location cmake.bin)"
""",
    outs = [
        "cmake.bin",
    ],
    visibility = [
        "//visibility:public",
    ]
)
