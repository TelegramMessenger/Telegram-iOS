// swift-tools-version: 5.9
import PackageDescription

let oh264 = "third_party/openh264_codec"

let package = Package(
    name: "subcodec",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
    ],
    products: [
        .library(name: "SubcodecObjC", targets: ["SubcodecObjC"]),
    ],
    targets: [
        .target(
            name: "oh264_common",
            path: "\(oh264)/common",
            exclude: [
                "arm", "arm64", "x86", "mips", "loongarch",
            ],
            sources: ["src"],
            publicHeadersPath: "inc",
            cxxSettings: [
                .headerSearchPath("../api/wels"),
                .unsafeFlags(["-w", "-std=c++11"]),
            ]
        ),
        .target(
            name: "oh264_processing",
            dependencies: ["oh264_common"],
            path: "\(oh264)/processing",
            exclude: [
                "src/arm", "src/arm64", "src/x86", "src/mips", "src/loongarch",
                "src/common/WelsVP.rc", "src/common/WelsVP.def",
            ],
            sources: ["src"],
            publicHeadersPath: "interface",
            cxxSettings: [
                .headerSearchPath("src/common"),
                .headerSearchPath("../common/inc"),
                .headerSearchPath("../api/wels"),
                .unsafeFlags(["-w", "-std=c++11"]),
            ]
        ),
        .target(
            name: "oh264_encoder",
            dependencies: ["oh264_common", "oh264_processing"],
            path: "\(oh264)/encoder",
            exclude: [
                "core/arm", "core/arm64", "core/x86", "core/mips", "core/loongarch",
                "plus/src/DllEntry.cpp", "plus/src/wels_enc_export.def",
            ],
            sources: ["core/src", "plus/src"],
            publicHeadersPath: "core/inc",
            cxxSettings: [
                .headerSearchPath("plus/inc"),
                .headerSearchPath("../common/inc"),
                .headerSearchPath("../api/wels"),
                .headerSearchPath("../processing/interface"),
                .unsafeFlags(["-w", "-std=c++11"]),
            ]
        ),
        .target(
            name: "oh264_decoder",
            dependencies: ["oh264_common"],
            path: "\(oh264)/decoder",
            exclude: [
                "core/arm", "core/arm64", "core/x86", "core/mips", "core/loongarch",
                "plus/src/wels_dec_export.def",
            ],
            sources: ["core/src", "plus/src"],
            publicHeadersPath: "core/inc",
            cxxSettings: [
                .headerSearchPath("plus/inc"),
                .headerSearchPath("../common/inc"),
                .headerSearchPath("../api/wels"),
                .unsafeFlags(["-w", "-std=c++11"]),
            ]
        ),
        .target(
            name: "h264bitstream",
            path: "third_party/h264bitstream",
            sources: ["h264_stream.c", "h264_nal.c", "h264_sei.c"],
            publicHeadersPath: "."
        ),
        .target(
            name: "sprite_encode",
            dependencies: ["subcodec", "oh264_common", "oh264_processing", "oh264_encoder", "oh264_decoder"],
            path: "Sources/SpriteEncode",
            cxxSettings: [
                .headerSearchPath("../../src"),
                .headerSearchPath("../../third_party/h264bitstream"),
                .headerSearchPath("../../\(oh264)/api/wels"),
                .headerSearchPath("../../\(oh264)/encoder/core/inc"),
                .headerSearchPath("../../\(oh264)/encoder/plus/inc"),
                .headerSearchPath("../../\(oh264)/decoder/core/inc"),
                .headerSearchPath("../../\(oh264)/decoder/plus/inc"),
                .headerSearchPath("../../\(oh264)/common/inc"),
                .unsafeFlags(["-std=c++23"]),
            ]
        ),
        .target(
            name: "subcodec",
            dependencies: ["h264bitstream"],
            path: "src",
            exclude: ["sprite_encode.cpp", "sprite_extractor.cpp"],
            publicHeadersPath: ".",
            cxxSettings: [
                .headerSearchPath("../third_party/h264bitstream"),
            ]
        ),
        .target(
            name: "SubcodecObjC",
            dependencies: ["subcodec", "sprite_encode"],
            path: "Sources/SubcodecObjC",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("../../src"),
                .headerSearchPath("../../third_party/h264bitstream"),
                .headerSearchPath("../../\(oh264)/api/wels"),
                .headerSearchPath("../../\(oh264)/common/inc"),
                .headerSearchPath("../../\(oh264)/encoder/core/inc"),
                .headerSearchPath("../../\(oh264)/decoder/core/inc"),
            ],
            linkerSettings: [
                .linkedFramework("VideoToolbox"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
            ]
        ),
        .testTarget(
            name: "SubcodecTests",
            dependencies: ["SubcodecObjC"],
            path: "Tests/SubcodecTests",
            exclude: ["generate_fixtures.cpp"],
            resources: [.copy("Fixtures")]
        ),
    ],
    cxxLanguageStandard: .cxx2b
)
