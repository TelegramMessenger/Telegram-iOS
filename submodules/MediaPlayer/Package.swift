// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TelegramMediaPlayer",
    platforms: [.macOS(.v10_13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "TelegramMediaPlayer",
            targets: ["TelegramMediaPlayer"]),
    ],
    dependencies: [
        .package(name: "TelegramCore", path: "../TelegramCore"),
        .package(name: "Postbox", path: "../Postbox"),
        .package(name: "FFMpegBinding", path: "../FFMpegBinding"),
        .package(name: "YuvConversion", path: "../YuvConversion"),
        .package(name: "RingBuffer", path: "../RingBuffer"),
        .package(name: "TGUIKit", path: "../../../../packages/TGUIKit"),

        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "TelegramMediaPlayer",
            dependencies: [.product(name: "TelegramCore", package: "TelegramCore", condition: nil),
                           .product(name: "Postbox", package: "Postbox", condition: nil),
                           .product(name: "FFMpegBinding", package: "FFMpegBinding", condition: nil),
                           .product(name: "YuvConversion", package: "YuvConversion", condition: nil),
                           .product(name: "RingBuffer", package: "RingBuffer", condition: nil),
                           .product(name: "TGUIKit", package: "TGUIKit", condition: nil),
            ],
            path: "Sources",
            exclude: ["MediaPlayer.swift",
                      "MediaPlayerScrubbingNode.swift",
                      "MediaPlayerTimeTextNode.swift",
                      "MediaPlayerNode.swift",
                      "MediaPlayerAudioRenderer.swift",
                      "MediaPlayerFramePreview.swift",
                      "VideoPlayerProxy.swift",
                      "ChunkMediaPlayer.swift",
                      "ChunkMediaPlayerV2.swift"
                     ]),
    ]
)
