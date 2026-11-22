// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OpusKit",
    platforms: [
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "OpusKit", targets: ["OpusKit"]),
    ],
    targets: [
        .target(
            name: "COgg",
            path: "Sources/COgg",
            sources: ["libogg/src"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("libogg/include"),
            ]
        ),
        // Vendored: libopus 1.5.2 (https://opus-codec.org).
        // Exclude list is version-specific — verify on upgrade.
        // arm_celt_map.c and armcpu.c are intentionally kept; both are fully
        // wrapped in `#ifdef OPUS_HAVE_RTCD` (never defined here) and compile
        // to empty TUs. arm_silk_map.c is excluded because it unconditionally
        // includes main_FIX.h from the (excluded) silk/fixed tree.
        .target(
            name: "COpus",
            path: "Sources/COpus",
            exclude: [
                // NEON (ARM) SIMD variants — disabled via -U__ARM_NEON__
                "libopus/celt/arm/celt_neon_intr.c",
                "libopus/celt/arm/pitch_neon_intr.c",
                "libopus/silk/arm/biquad_alt_neon_intr.c",
                "libopus/silk/arm/LPC_inv_pred_gain_neon_intr.c",
                "libopus/silk/arm/NSQ_del_dec_neon_intr.c",
                "libopus/silk/arm/NSQ_neon.c",
                // ARM dispatcher — unconditionally includes silk/fixed headers (excluded)
                "libopus/silk/arm/arm_silk_map.c",
                // (silk/fixed/arm files already covered by the silk/fixed directory exclude below)
                // ARM .s assembly (GAS/RVCT)
                "libopus/celt/arm/celt_pitch_xcorr_arm.s",
                "libopus/celt/arm/celt_pitch_xcorr_arm-gnu.S",
                // ARM NE10 FFT (external dep) — not used
                "libopus/celt/arm/celt_mdct_ne10.c",
                "libopus/celt/arm/celt_fft_ne10.c",
                // x86 (SSE/AVX) intrinsic variants
                "libopus/celt/x86/celt_lpc_sse4_1.c",
                "libopus/celt/x86/pitch_sse.c",
                "libopus/celt/x86/pitch_sse2.c",
                "libopus/celt/x86/pitch_sse4_1.c",
                "libopus/celt/x86/pitch_avx.c",
                "libopus/celt/x86/vq_sse2.c",
                "libopus/celt/x86/x86_celt_map.c",
                "libopus/celt/x86/x86cpu.c",
                "libopus/silk/x86/NSQ_del_dec_sse4_1.c",
                "libopus/silk/x86/NSQ_del_dec_avx2.c",
                "libopus/silk/x86/NSQ_sse4_1.c",
                "libopus/silk/x86/VAD_sse4_1.c",
                "libopus/silk/x86/VQ_WMat_EC_sse4_1.c",
                "libopus/silk/x86/x86_silk_map.c",
                "libopus/silk/fixed/x86/burg_modified_FIX_sse4_1.c",
                "libopus/silk/fixed/x86/vector_ops_FIX_sse4_1.c",
                "libopus/silk/float/x86/inner_product_FLP_avx2.c",
                // libopus example / test programs
                "libopus/src/opus_compare.c",
                "libopus/src/opus_demo.c",
                "libopus/src/repacketizer_demo.c",
                "libopus/celt/opus_custom_demo.c",
                "libopus/celt/tests",
                "libopus/silk/tests",
                // Fixed-point silk — we're a float build (FIXED_POINT undefined)
                "libopus/silk/fixed",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("libopus"),
                .headerSearchPath("libopus/include"),
                .headerSearchPath("libopus/celt"),
                .headerSearchPath("libopus/silk"),
                .headerSearchPath("libopus/silk/float"),
                .headerSearchPath("libopus/src"),
                .define("HAVE_CONFIG_H"),
                .unsafeFlags(["-U__ARM_NEON__", "-U__SSE2__", "-U__SSE4_1__", "-U__AVX2__"]),
            ]
        ),
        .target(
            name: "COpusHelpers",
            dependencies: ["COpus"],
            path: "Sources/COpusHelpers",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("../COpus/include"),
            ]
        ),
        .target(
            name: "OpusKit",
            dependencies: ["COgg", "COpus", "COpusHelpers"],
            path: "Sources/OpusKit"
        ),
        .testTarget(
            name: "OpusKitTests",
            dependencies: ["OpusKit"],
            path: "Tests/OpusKitTests",
            resources: [
                .copy("Resources/voice_note.ogg"),
            ]
        ),
    ],
    cLanguageStandard: .c11
)
