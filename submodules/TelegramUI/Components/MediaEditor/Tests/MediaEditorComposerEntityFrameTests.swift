import Foundation
import UIKit
import Metal
import CoreImage
import CoreVideo
import AVFoundation
import Postbox
import TelegramCore
import Display
@testable import MediaEditor

private let entityFrameColorSpace = CGColorSpaceCreateDeviceRGB()

struct MediaEditorComposerEntityFrameKind {
    let name: String
    let testName: String
    let times: [Double]
    let makeEntity: (Postbox) -> MediaEditorComposerEntity?
}

private func stickerComposerEntity(_ postbox: Postbox, _ content: DrawingStickerEntity.Content, tintColor: UIColor? = nil) -> MediaEditorComposerEntity? {
    let entity = DrawingStickerEntity(content: content)
    entity.referenceDrawingSize = MediaEditorExportFixtures.storyDimensions
    entity.position = CGPoint(x: 540.0, y: 960.0)
    return composerEntitiesForDrawingEntity(postbox: postbox, textScale: 2.0, entity: entity, colorSpace: entityFrameColorSpace, tintColor: tintColor).first
}

private func animatedImageFrameTime(index: Int) -> Double {
    guard let animatedImage = UIImage.animatedImageFromData(data: MediaEditorExportFixtures.data("animation.heics")), animatedImage.duration > 0.0 else {
        return 0.0
    }
    let frameTime = animatedImage.duration / Double(animatedImage.images.count)
    return (Double(index) + 0.5) * frameTime
}

let mediaEditorComposerEntityFrameKinds: [MediaEditorComposerEntityFrameKind] = [
    MediaEditorComposerEntityFrameKind(name: "static-image", testName: "testStaticImageFrameMatchesPreview", times: [0.0], makeEntity: { postbox in
        return stickerComposerEntity(postbox, .image(MediaEditorExportFixtures.stickerImage, .sticker))
    }),
    MediaEditorComposerEntityFrameKind(name: "gif", testName: "testAnimatedImageFrameMatchesPreview", times: [animatedImageFrameTime(index: 2)], makeEntity: { postbox in
        let data = MediaEditorExportFixtures.data("animation.heics")
        return stickerComposerEntity(postbox, .animatedImage(data, UIImage(data: data)!))
    }),
    MediaEditorComposerEntityFrameKind(name: "lottie", testName: "testLottieFrameMatchesPreview", times: [0.0, 0.5], makeEntity: { postbox in
        return stickerComposerEntity(postbox, .file(.standalone(media: MediaEditorExportFixtures.tgsFile), .sticker))
    }),
    MediaEditorComposerEntityFrameKind(name: "tinted-lottie", testName: "testTintedLottieFrameMatchesPreview", times: [0.0, 0.5], makeEntity: { postbox in
        return stickerComposerEntity(postbox, .file(.standalone(media: MediaEditorExportFixtures.templateEmojiFile), .sticker), tintColor: UIColor(rgb: 0xff8a00))
    }),
    MediaEditorComposerEntityFrameKind(name: "webm", testName: "testVideoStickerFrameMatchesPreview", times: [0.0, 0.5], makeEntity: { postbox in
        return stickerComposerEntity(postbox, .file(.standalone(media: MediaEditorExportFixtures.webmFile), .sticker))
    }),
    MediaEditorComposerEntityFrameKind(name: "video", testName: "testVideoFrameWithMaskMatchesPreview", times: [0.0, 0.5], makeEntity: { postbox in
        return stickerComposerEntity(postbox, .video(MediaEditorExportFixtures.squareVideoFile))
    })
]

final class MediaEditorComposerEntityFrameSuite {
    static var testNames: [String] {
        return mediaEditorComposerEntityFrameKinds.map { $0.testName } + ["testPixelBufferColorConversionPaths"]
    }

    let device: MTLDevice
    let compositor: MediaEditorFrameCompositor
    let ciContext: CIContext

    private var failures: [String] = []
    private var measurements: [String] = []

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue(), let compositor = MediaEditorFrameCompositor(device: device, commandQueue: commandQueue) else {
            return nil
        }
        self.device = device
        self.compositor = compositor
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: entityFrameColorSpace])
    }

    func run(_ name: String) -> MediaEditorFrameCompositorCaseResult {
        self.failures = []
        self.measurements = []
        if let kind = mediaEditorComposerEntityFrameKinds.first(where: { $0.testName == name }) {
            self.check(kind)
        } else if name == "testPixelBufferColorConversionPaths" {
            self.testPixelBufferColorConversionPaths()
        } else {
            self.failures.append("unknown test \(name)")
        }
        return MediaEditorFrameCompositorCaseResult(name: name, failures: self.failures, measurements: self.measurements)
    }

    func runAll() -> [MediaEditorFrameCompositorCaseResult] {
        return MediaEditorComposerEntityFrameSuite.testNames.map { self.run($0) }
    }

    private func fail(_ message: String) {
        self.failures.append(message)
    }

    private func frame(_ kind: MediaEditorComposerEntityFrameKind) -> MediaEditorComposerEntityFrame? {
        guard let postbox = MediaEditorExportRunner.makePostbox() else {
            self.fail("\(kind.name): cannot open a temporary Postbox")
            return nil
        }
        MediaEditorExportFixtures.storeIfNeeded(in: postbox)
        guard let entity = kind.makeEntity(postbox) else {
            self.fail("\(kind.name): no composer entity")
            return nil
        }
        var result: MediaEditorComposerEntityFrame?
        for time in kind.times {
            let semaphore = DispatchSemaphore(value: 0)
            var frame: MediaEditorComposerEntityFrame?
            entity.frame(for: CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), frameRate: 30.0, completion: { value in
                frame = value
                semaphore.signal()
            })
            if semaphore.wait(timeout: .now() + 20.0) == .timedOut {
                self.fail("\(kind.name): timed out waiting for the frame at \(time)")
                return nil
            }
            result = frame
        }
        if result == nil {
            self.fail("\(kind.name): no frame")
        }
        return result
    }

    private func renderTexture(_ texture: MTLTexture) -> MediaEditorBitmap? {
        let scene = MediaEditorCompositionScene(outputSize: CGSize(width: texture.width, height: texture.height), background: nil, backgroundRect: .zero, layers: [MediaEditorCompositionLayer(texture: texture, origin: .topLeft, transform: .identity, alphaMask: nil)], finalMask: nil)
        guard let output = makeCompositorPixelBuffer(width: texture.width, height: texture.height), self.compositor.render(scene: scene, into: output), let image = cgImage(from: output) else {
            self.fail("compositor render failed")
            return nil
        }
        return MediaEditorBitmap(image)
    }

    private func testPixelBufferColorConversionPaths() {
        let pattern = makeCompositorPatternImage(width: 256, height: 256, transparentMargin: true)
        guard let pixelBuffer = makeCompositorPixelBuffer(width: 256, height: 256) else {
            self.fail("cannot create the BGRA buffer")
            return
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer), width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: entityFrameColorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)!
        context.setBlendMode(.copy)
        context.draw(pattern, in: CGRect(x: 0.0, y: 0.0, width: 256.0, height: 256.0))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        let raw = MediaEditorBitmap(cgImage(from: pixelBuffer)!)
        let cases: [(String, CGColorSpace, CGColorSpace?, Int?)] = [
            ("Display P3, no destination: unconverted", CGColorSpace(name: CGColorSpace.displayP3)!, nil, 0),
            ("DeviceRGB to DeviceRGB: unconverted", CGColorSpaceCreateDeviceRGB(), entityFrameColorSpace, 0),
            ("Display P3 to DeviceRGB on the GPU vs CoreGraphics", CGColorSpace(name: CGColorSpace.displayP3)!, entityFrameColorSpace, nil),
            ("Display P3 PQ to DeviceRGB through CoreGraphics", CGColorSpace(name: CGColorSpace.displayP3_PQ)!, entityFrameColorSpace, 0)
        ]
        for (label, source, destination, allowedMaxDelta) in cases {
            CVBufferSetAttachment(pixelBuffer, kCVImageBufferCGColorSpaceKey, source, .shouldPropagate)
            guard let texture = self.compositor.texture(for: pixelBuffer, convertingTo: destination), let actual = self.renderTexture(texture) else {
                self.fail("\(label): no texture")
                continue
            }
            var expected = raw
            if destination != nil, source != CGColorSpaceCreateDeviceRGB(), let tagged = cgImage(from: pixelBuffer)?.copy(colorSpace: source) {
                expected = MediaEditorBitmap(tagged)
            }
            self.compare(label, actual, expected, maxDelta: allowedMaxDelta)
        }
    }

    private func compare(_ label: String, _ actual: MediaEditorBitmap, _ reference: MediaEditorBitmap, maxDelta allowedMaxDelta: Int?) {
        guard actual.width == reference.width, actual.height == reference.height else {
            self.fail("\(label): size \(actual.width)x\(actual.height), reference \(reference.width)x\(reference.height)")
            return
        }
        let diff = comparePixels(actual, reference, edgeMask: edgeMask(for: reference))
        self.measurements.append("\(label): maxDelta=\(diff.maxDelta) maxNonEdgeDelta=\(diff.maxNonEdgeDelta) meanDelta=(\(String(format: "%.4f, %.4f, %.4f, %.4f", diff.meanDelta.x, diff.meanDelta.y, diff.meanDelta.z, diff.meanDelta.w))) outOfToleranceShare=\(String(format: "%.6f", diff.outOfToleranceShare)) edgeShare=\(String(format: "%.6f", diff.edgeShare))")
        if let allowedMaxDelta {
            if diff.maxDelta > allowedMaxDelta {
                self.fail("\(label): maxDelta \(diff.maxDelta) > \(allowedMaxDelta)")
            }
        } else {
            if diff.maxNonEdgeDelta > pixelDiffTolerance {
                self.fail("\(label): maxNonEdgeDelta \(diff.maxNonEdgeDelta) > \(pixelDiffTolerance)")
            }
            if diff.meanDelta.max() > 0.5 {
                self.fail("\(label): meanDelta \(diff.meanDelta) > 0.5")
            }
        }
    }

    private func check(_ kind: MediaEditorComposerEntityFrameKind) {
        guard let frame = self.frame(kind) else {
            return
        }
        let content: String
        let texture: MTLTexture?
        switch frame.content {
        case let .pixelBuffer(pixelBuffer):
            content = "pixelBuffer \(CVPixelBufferGetPixelFormatType(pixelBuffer))"
            texture = self.compositor.texture(for: pixelBuffer, convertingTo: entityFrameColorSpace)
        case let .image(image):
            content = "image"
            texture = self.compositor.texture(for: image)
        }
        self.measurements.append("\(kind.name): content \(content), alphaMask \(frame.alphaMask != nil)")
        if (kind.name == "video") != (frame.alphaMask != nil) {
            self.fail("\(kind.name): alphaMask \(frame.alphaMask != nil ? "present" : "absent")")
        }
        guard let texture else {
            self.fail("\(kind.name): no texture for the frame")
            return
        }
        var alphaMask: MTLTexture?
        if let mask = frame.alphaMask {
            alphaMask = self.compositor.texture(for: mask)
            if alphaMask == nil {
                self.fail("\(kind.name): no texture for the alpha mask")
                return
            }
        }
        guard let preview = mediaEditorEntityFrameCIImage(frame, colorSpace: entityFrameColorSpace) else {
            self.fail("\(kind.name): no preview CIImage")
            return
        }
        let extent = preview.extent
        guard let previewBuffer = makeCompositorPixelBuffer(width: Int(extent.width), height: Int(extent.height)) else {
            self.fail("\(kind.name): no preview buffer")
            return
        }
        self.ciContext.render(preview.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY)), to: previewBuffer)
        guard let previewImage = cgImage(from: previewBuffer) else {
            self.fail("\(kind.name): cannot read the preview buffer")
            return
        }
        let size = CGSize(width: texture.width, height: texture.height)
        let scene = MediaEditorCompositionScene(outputSize: size, background: nil, backgroundRect: .zero, layers: [MediaEditorCompositionLayer(texture: texture, origin: .topLeft, transform: .identity, alphaMask: alphaMask)], finalMask: nil)
        if let output = makeCompositorPixelBuffer(width: texture.width, height: texture.height), self.compositor.render(scene: scene, into: output), let metal = cgImage(from: output) {
            self.compare("\(kind.name) compositor vs mediaEditorEntityFrameCIImage", MediaEditorBitmap(metal), MediaEditorBitmap(previewImage), maxDelta: nil)
        } else {
            self.fail("\(kind.name): compositor render failed")
        }
    }
}
