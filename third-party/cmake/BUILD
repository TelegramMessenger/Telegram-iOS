
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

    export PATH=/usr/bin:/bin:/usr/sbin:/sbin

    core_count="`sysctl -n hw.logicalcpu`"
    ./bootstrap --parallel=$$core_count -- -DCMAKE_BUILD_TYPE:STRING=Release
    make -j $$core_count

    popd

    tar -cf "$(location cmake.tar)" -C "$$BUILD_DIR/cmake-3.16.0" .
""",
    outs = [
        "cmake.tar",
    ],
    visibility = [
        "//visibility:public",
    ]
)
