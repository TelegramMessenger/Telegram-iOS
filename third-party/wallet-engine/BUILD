load("@rules_cc//cc:objc_library.bzl", "objc_library")

load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load(
    "@rules_rust//rust:defs.bzl",
    "rust_binary",
    "rust_library",
    "rust_shared_library",
    "rust_static_library",
)

_RUST_RELEASE_FLAGS = [
    "-Ccodegen-units=1",
    "-Copt-level=z",
    "-Cpanic=abort",
]

rust_library(
    name = "ton",
    crate_name = "ton",
    crate_root = "wallet-engine/vendor/ton/src/lib.rs",
    compile_data = ["wallet-engine/vendor/ton/Cargo.toml"] + glob(["wallet-engine/vendor/ton/resources/**"]),
    edition = "2024",
    proc_macro_deps = ["@wallet_engine_crates//:ton_macros"],
    rustc_env_files = ["RustEnv/ton.env"],
    rustc_flags = _RUST_RELEASE_FLAGS,
    srcs = glob(["wallet-engine/vendor/ton/src/**/*.rs"]),
    version = "0.1.3",
    deps = [
        "@wallet_engine_crates//:base64",
        "@wallet_engine_crates//:ed25519-dalek",
        "@wallet_engine_crates//:fastnum",
        "@wallet_engine_crates//:hex",
        "@wallet_engine_crates//:hmac",
        "@wallet_engine_crates//:num-bigint",
        "@wallet_engine_crates//:num-traits",
        "@wallet_engine_crates//:parking_lot",
        "@wallet_engine_crates//:pbkdf2",
        "@wallet_engine_crates//:serde",
        "@wallet_engine_crates//:serde-aux",
        "@wallet_engine_crates//:serde_json",
        "@wallet_engine_crates//:sha2",
        "@wallet_engine_crates//:thiserror",
        "@wallet_engine_crates//:ton_core",
        "@wallet_engine_crates//:zeroize",
    ],
)

rust_library(
    name = "ton_connect_core",
    crate_name = "ton_connect_core",
    crate_root = "wallet-engine/crates/ton-connect-core/src/lib.rs",
    compile_data = glob(["wallet-engine/crates/ton-connect-core/src/testdata/**"]),
    edition = "2024",
    rustc_flags = _RUST_RELEASE_FLAGS,
    srcs = glob(["wallet-engine/crates/ton-connect-core/src/**/*.rs"]),
    version = "0.0.6",
    deps = [
        "@wallet_engine_crates//:base64",
        "@wallet_engine_crates//:crc",
        "@wallet_engine_crates//:crypto_box",
        "@wallet_engine_crates//:ed25519-dalek",
        "@wallet_engine_crates//:getrandom",
        "@wallet_engine_crates//:hex",
        "@wallet_engine_crates//:serde",
        "@wallet_engine_crates//:serde_json",
        "@wallet_engine_crates//:sha2",
        "@wallet_engine_crates//:thiserror",
        "@wallet_engine_crates//:ton_core",
        "@wallet_engine_crates//:url",
        "@wallet_engine_crates//:zeroize",
    ],
)

rust_library(
    name = "ton_connect_client",
    crate_name = "ton_connect_client",
    crate_root = "wallet-engine/crates/ton-connect-client/src/lib.rs",
    edition = "2024",
    rustc_flags = _RUST_RELEASE_FLAGS,
    srcs = glob(["wallet-engine/crates/ton-connect-client/src/**/*.rs"]),
    version = "0.0.6",
    deps = [
        ":ton_connect_core",
        "@wallet_engine_crates//:serde",
        "@wallet_engine_crates//:serde_json",
        "@wallet_engine_crates//:thiserror",
        "@wallet_engine_crates//:url",
    ],
)

_WALLET_ENGINE_DEPS = [
    ":ton",
    ":ton_connect_client",
    ":ton_connect_core",
    "@wallet_engine_crates//:aes",
    "@wallet_engine_crates//:base64",
    "@wallet_engine_crates//:curve25519-dalek",
    "@wallet_engine_crates//:ed25519-dalek",
    "@wallet_engine_crates//:futures",
    "@wallet_engine_crates//:getrandom",
    "@wallet_engine_crates//:hmac",
    "@wallet_engine_crates//:num-bigint",
    "@wallet_engine_crates//:pbkdf2",
    "@wallet_engine_crates//:serde",
    "@wallet_engine_crates//:serde_json",
    "@wallet_engine_crates//:sha2",
    "@wallet_engine_crates//:subtle",
    "@wallet_engine_crates//:thiserror",
    "@wallet_engine_crates//:uniffi",
    "@wallet_engine_crates//:url",
    "@wallet_engine_crates//:zeroize",
]

_WALLET_ENGINE_SRCS = glob(["wallet-engine/src/**/*.rs"])
_WALLET_ENGINE_COMPILE_DATA = ["wallet-engine/Cargo.toml"]
_WALLET_ENGINE_RUSTC_ENV_FILES = ["RustEnv/wallet-engine.env"]
_WALLET_ENGINE_METADATA_INPUTS = [
    "wallet-engine/Cargo.lock",
    "wallet-engine/Cargo.toml",
    "wallet-engine/uniffi.toml",
    "wallet-engine/crates/ton-connect-client/Cargo.toml",
    "wallet-engine/crates/ton-connect-core/Cargo.toml",
    "wallet-engine/vendor/ton/Cargo.toml",
] + _WALLET_ENGINE_SRCS + glob([
    "wallet-engine/tests/**/*.rs",
    "wallet-engine/crates/ton-connect-client/src/**/*.rs",
    "wallet-engine/crates/ton-connect-client/tests/**/*.rs",
    "wallet-engine/crates/ton-connect-core/src/**/*.rs",
    "wallet-engine/crates/ton-connect-core/tests/**/*.rs",
])

rust_static_library(
    name = "wallet_engine_archive",
    crate_name = "wallet_engine",
    crate_root = "wallet-engine/src/lib.rs",
    compile_data = _WALLET_ENGINE_COMPILE_DATA,
    edition = "2024",
    proc_macro_deps = ["@wallet_engine_crates//:async-trait"],
    rustc_env_files = _WALLET_ENGINE_RUSTC_ENV_FILES,
    rustc_flags = _RUST_RELEASE_FLAGS,
    srcs = _WALLET_ENGINE_SRCS,
    version = "0.0.6",
    deps = _WALLET_ENGINE_DEPS,
)

rust_shared_library(
    name = "wallet_engine_bindings_cdylib",
    crate_name = "wallet_engine",
    crate_root = "wallet-engine/src/lib.rs",
    compile_data = _WALLET_ENGINE_COMPILE_DATA,
    edition = "2024",
    proc_macro_deps = ["@wallet_engine_crates//:async-trait"],
    rustc_env_files = _WALLET_ENGINE_RUSTC_ENV_FILES,
    rustc_flags = _RUST_RELEASE_FLAGS,
    srcs = _WALLET_ENGINE_SRCS,
    tags = ["manual"],
    version = "0.0.6",
    deps = _WALLET_ENGINE_DEPS,
)

rust_binary(
    name = "wallet_engine_apple_bindgen",
    crate_name = "wallet_engine_apple_bindgen",
    crate_root = "wallet-engine/bindgen/apple/src/main.rs",
    edition = "2024",
    srcs = ["wallet-engine/bindgen/apple/src/main.rs"],
    tags = ["manual"],
    deps = ["@wallet_engine_bindgen_crates//:uniffi"],
)

rust_binary(
    name = "wallet_engine_swift_postprocess",
    crate_name = "wallet_engine_swift_postprocess",
    crate_root = "Sources/SwiftBindingsPostprocess.rs",
    edition = "2024",
    srcs = [
        "Sources/SwiftBindingsPostprocess.rs",
        "wallet-engine/xtask/src/bindings/swift_postprocess.rs",
    ],
    tags = ["manual"],
    deps = ["@wallet_engine_bindgen_crates//:anyhow"],
)

genrule(
    name = "wallet_engine_swift_bindings",
    srcs = _WALLET_ENGINE_METADATA_INPUTS,
    outs = [
        "Generated/WalletEngineFFI.swift",
        "Generated/wallet_engineFFI.h",
    ],
    cmd_bash = """
    set -euo pipefail

    EXEC_ROOT="$$(pwd)"
    UPSTREAM_ROOT="$$EXEC_ROOT/third-party/wallet-engine/wallet-engine"
    BUILD_ROOT="$$EXEC_ROOT/$(RULEDIR)/swift-bindings-generated"
    SWIFT_OUTPUT="$$EXEC_ROOT/$(location Generated/WalletEngineFFI.swift)"
    HEADER_OUTPUT="$$EXEC_ROOT/$(location Generated/wallet_engineFFI.h)"
    CARGO_BIN="$$EXEC_ROOT/$(location @rules_rust//rust/toolchain:current_cargo_files)"
    BINDGEN_BIN="$$EXEC_ROOT/$(location :wallet_engine_apple_bindgen)"
    BINDINGS_LIBRARY="$$EXEC_ROOT/$(location :wallet_engine_bindings_cdylib)"

    rm -rf "$$BUILD_ROOT"
    mkdir -p "$$BUILD_ROOT"

    cd "$$UPSTREAM_ROOT"
    CARGO="$$CARGO_BIN" CARGO_NET_OFFLINE=true "$$BINDGEN_BIN" \
        --swift-sources \
        --headers \
        --modulemap \
        --metadata-no-deps \
        --module-name wallet_engineFFI \
        --modulemap-filename module.modulemap \
        "$$BINDINGS_LIBRARY" \
        "$$BUILD_ROOT"

    cd "$$EXEC_ROOT"
    "$$EXEC_ROOT/$(location :wallet_engine_swift_postprocess)" \
        "$$BUILD_ROOT/WalletEngineFFI.swift" \
        "$$SWIFT_OUTPUT" \
        "$$BUILD_ROOT/wallet_engineFFI.h" \
        "$$HEADER_OUTPUT"
    """,
    tools = [
        "@rules_rust//rust/toolchain:current_cargo_files",
        ":wallet_engine_apple_bindgen",
        ":wallet_engine_bindings_cdylib",
        ":wallet_engine_swift_postprocess",
    ],
    visibility = ["//visibility:public"],
)

objc_library(
    name = "wallet_engine",
    deps = [":wallet_engine_archive"],
    sdk_frameworks = [
        "Foundation",
        "Security",
    ],
    visibility = ["//visibility:public"],
)

objc_library(
    name = "wallet_engine_ffi",
    module_name = "wallet_engineFFI",
    enable_modules = True,
    hdrs = [":Generated/wallet_engineFFI.h"],
    deps = [":wallet_engine"],
)

swift_library(
    name = "WalletEngineFFI",
    module_name = "WalletEngineFFI",
    srcs = [":Generated/WalletEngineFFI.swift"],
    copts = [
        "-swift-version",
        "6",
        "-suppress-warnings",
    ],
    deps = [":wallet_engine_ffi"],
    visibility = ["//visibility:public"],
)
