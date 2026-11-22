// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RLottieKit",
    platforms: [
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "RLottieKit", targets: ["RLottieKit"]),
    ],
    targets: [
        .target(
            name: "RLottieCore",
            path: "Sources/RLottieCore",
            exclude: [
                // License files — not source
                "rlottie/COPYING",
                "rlottie/COPYING.MIT",
                // C API surface — we use the C++ Animation:: interface directly.
                // lottieitem_capi.cpp is NOT excluded: it contains buildLayerNode()
                // implementations for SolidLayer/ImageLayer/CompLayer/Layer and
                // Drawable::sync(), all of which are required to satisfy vtables.
                "rlottie/inc/rlottie_capi.h",
                "rlottie/src/binding/c/lottieanimation_capi.cpp",
                // WASM build — skip on Apple platforms
                "rlottie/src/wasm",
                // NEON acceleration calls external pixman assembly (.S) which
                // SPM won't assemble; vdrawhelper.cpp provides the scalar fallback
                // when __ARM_NEON__ is not defined.
                "rlottie/src/vector/vdrawhelper_neon.cpp",
                // Pixman assembly — not assembled by SPM; NEON path excluded above
                "rlottie/src/vector/pixman",
            ],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("rlottie/inc"),
                .headerSearchPath("rlottie/src"),
                .headerSearchPath("rlottie/src/lottie"),
                .headerSearchPath("rlottie/src/vector"),
                .headerSearchPath("rlottie/src/vector/freetype"),
                .headerSearchPath("rlottie/src/vector/stb"),
                .define("LOT_BUILD"),
                .define("NDEBUG"),
                // Disable NEON intrinsics: vdrawhelper_neon.cpp is excluded (it pulls
                // in pixman .S assembly that SPM won't assemble). Undefining __ARM_NEON__
                // activates the scalar memfill32 fallback in vdrawhelper.cpp and prevents
                // RenderFuncTable::RenderFuncTable() from calling the missing neon() stub.
                .unsafeFlags(["-U__ARM_NEON__"]),
            ]
        ),
        .target(
            name: "RLottieKit",
            dependencies: ["RLottieCore"],
            path: "Sources/RLottieKit",
            linkerSettings: [
                .linkedLibrary("z"),
            ]
        ),
        .testTarget(
            name: "RLottieKitTests",
            dependencies: ["RLottieKit"],
            path: "Tests/RLottieKitTests",
            resources: [
                .copy("Resources/tiny.tgs"),
                .copy("Resources/tiny.json"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
