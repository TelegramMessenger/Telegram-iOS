// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WebPKit",
    platforms: [
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "WebPKit", targets: ["WebPKit"]),
    ],
    targets: [
        .target(
            name: "WebPCore",
            path: "Sources/WebPCore",
            exclude: [
                "libwebp/COPYING",
                // NEON (ARM) SIMD variants — disabled via -U__ARM_NEON__
                "libwebp/src/dsp/cost_neon.c",
                "libwebp/src/dsp/dec_neon.c",
                "libwebp/src/dsp/enc_neon.c",
                "libwebp/src/dsp/filters_neon.c",
                "libwebp/src/dsp/lossless_enc_neon.c",
                "libwebp/src/dsp/lossless_neon.c",
                "libwebp/src/dsp/rescaler_neon.c",
                "libwebp/src/dsp/upsampling_neon.c",
                "libwebp/src/dsp/yuv_neon.c",
                "libwebp/src/dsp/alpha_processing_neon.c",
                // SSE2/SSE4.1 (x86) SIMD variants — disabled via -U__SSE2__ / -U__SSE4_1__
                "libwebp/src/dsp/cost_sse2.c",
                "libwebp/src/dsp/dec_sse2.c",
                "libwebp/src/dsp/dec_sse41.c",
                "libwebp/src/dsp/enc_sse2.c",
                "libwebp/src/dsp/enc_sse41.c",
                "libwebp/src/dsp/filters_sse2.c",
                "libwebp/src/dsp/lossless_enc_sse2.c",
                "libwebp/src/dsp/lossless_enc_sse41.c",
                "libwebp/src/dsp/lossless_sse2.c",
                "libwebp/src/dsp/lossless_sse41.c",
                "libwebp/src/dsp/rescaler_sse2.c",
                "libwebp/src/dsp/upsampling_sse2.c",
                "libwebp/src/dsp/upsampling_sse41.c",
                "libwebp/src/dsp/yuv_sse2.c",
                "libwebp/src/dsp/yuv_sse41.c",
                "libwebp/src/dsp/alpha_processing_sse2.c",
                "libwebp/src/dsp/alpha_processing_sse41.c",
                "libwebp/src/dsp/ssim_sse2.c",
                // MIPS variants
                "libwebp/src/dsp/cost_mips32.c",
                "libwebp/src/dsp/cost_mips_dsp_r2.c",
                "libwebp/src/dsp/dec_mips32.c",
                "libwebp/src/dsp/dec_mips_dsp_r2.c",
                "libwebp/src/dsp/dec_msa.c",
                "libwebp/src/dsp/enc_mips32.c",
                "libwebp/src/dsp/enc_mips_dsp_r2.c",
                "libwebp/src/dsp/enc_msa.c",
                "libwebp/src/dsp/filters_mips_dsp_r2.c",
                "libwebp/src/dsp/filters_msa.c",
                "libwebp/src/dsp/lossless_enc_mips32.c",
                "libwebp/src/dsp/lossless_enc_mips_dsp_r2.c",
                "libwebp/src/dsp/lossless_enc_msa.c",
                "libwebp/src/dsp/lossless_mips_dsp_r2.c",
                "libwebp/src/dsp/lossless_msa.c",
                "libwebp/src/dsp/rescaler_mips32.c",
                "libwebp/src/dsp/rescaler_mips_dsp_r2.c",
                "libwebp/src/dsp/rescaler_msa.c",
                "libwebp/src/dsp/upsampling_mips_dsp_r2.c",
                "libwebp/src/dsp/upsampling_msa.c",
                "libwebp/src/dsp/yuv_mips32.c",
                "libwebp/src/dsp/yuv_mips_dsp_r2.c",
                "libwebp/src/dsp/alpha_processing_mips_dsp_r2.c",
                // Encoder-side DSP (no src/enc/ was copied; these reference vp8i_enc.h or enc-only types)
                "libwebp/src/dsp/enc.c",
                "libwebp/src/dsp/lossless_enc.c",
                "libwebp/src/dsp/ssim.c",
                // Encoder-side utils
                "libwebp/src/utils/bit_writer_utils.c",
                "libwebp/src/utils/huffman_encode_utils.c",
                "libwebp/src/utils/quant_levels_utils.c",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("libwebp"),
                .headerSearchPath("libwebp/src"),
                .define("WEBP_USE_THREAD", to: "0"),
                .define("NDEBUG"),
                // HAVE_CONFIG_H suppresses the automatic __aarch64__ → WEBP_USE_NEON
                // detection in cpu.h (line 91-95). Without WEBP_HAVE_NEON also defined,
                // the NEON dispatch stubs are compiled out — matching our exclusion of
                // the NEON .c files from the target.
                .define("HAVE_CONFIG_H"),
                .unsafeFlags(["-U__ARM_NEON__", "-U__SSE2__", "-U__SSE4_1__"]),
            ]
        ),
        .target(
            name: "WebPKit",
            dependencies: ["WebPCore"],
            path: "Sources/WebPKit"
        ),
        .testTarget(
            name: "WebPKitTests",
            dependencies: ["WebPKit"],
            path: "Tests/WebPKitTests",
            resources: [
                .copy("Resources/sticker_raster.webp"),
            ]
        ),
    ],
    cLanguageStandard: .c11
)
