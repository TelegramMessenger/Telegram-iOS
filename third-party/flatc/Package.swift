// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "FlatBuffersBuilder",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .plugin(
            name: "FlatBuffersPlugin",
            targets: ["FlatBuffersPlugin"]
        )
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "flatc",
            url: "https://github.com/google/flatbuffers/releases/download/v23.5.26/Mac.flatc.binary.zip",
            checksum: "d65628c225ef26e0386df003fe47d6b3ec8775c586d7dae1a9ef469a0a9906f1"
        ),
        .plugin(
            name: "FlatBuffersPlugin",
            capability: .buildTool(),
            dependencies: ["flatc"]
        )
    ]
)
