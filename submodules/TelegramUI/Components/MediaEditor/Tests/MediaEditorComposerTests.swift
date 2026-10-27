import Foundation
import UIKit
import Metal
import CoreVideo
import AVFoundation
import TelegramCore
@testable import MediaEditor

private final class MediaEditorComposerStubEntity: MediaEditorComposerEntity {
    let position: CGPoint
    let scale: CGFloat = 1.0
    let rotation: CGFloat = 0.3
    let baseSize: CGSize? = nil
    let baseScale: CGFloat? = 1.0
    let baseDrawingSize: CGSize? = nil
    let mirrored: Bool = false
    private let result: MediaEditorComposerEntityFrame?

    init(position: CGPoint, frame: MediaEditorComposerEntityFrame?) {
        self.position = position
        self.result = frame
    }

    func frame(for time: CMTime, frameRate: Float, completion: @escaping (MediaEditorComposerEntityFrame?) -> Void) {
        let result = self.result
        DispatchQueue.global().async {
            completion(result)
        }
    }
}

let mediaEditorComposerExpectedCoreImageFiles = [
    "ImageObjectClassification.swift",
    "MediaEditorComposer.swift",
    "MediaEditorRenderer.swift",
    "StickerOutlineRenderPass.swift",
    "UniversalTextureSource.swift",
    "VideoInputPass.swift"
]

private let mediaEditorCoreImageTokens = ["CIImage", "CIContext", "CIFilter"]

private func mentionsCoreImage(_ text: String) -> Bool {
    return mediaEditorCoreImageTokens.contains(where: { text.contains($0) })
}

func mediaEditorBraceBlock(in text: String, from start: String.Index) -> Range<String.Index>? {
    guard let open = text[start...].firstIndex(of: "{") else {
        return nil
    }
    var depth = 0
    var index = open
    while index < text.endIndex {
        let character = text[index]
        if character == "{" {
            depth += 1
        } else if character == "}" {
            depth -= 1
            if depth == 0 {
                return open ..< text.index(after: index)
            }
        }
        index = text.index(after: index)
    }
    return nil
}

final class MediaEditorComposerSuite {
    static let testNames = [
        "testNilEntityFrameStillCompletesFrame",
        "testCompositionUsesNoCoreImage",
        "testConvertedEntityTexturesAreReusedAcrossFrames"
    ]

    private var failures: [String] = []
    private var measurements: [String] = []

    func run(_ name: String) -> MediaEditorFrameCompositorCaseResult {
        self.failures = []
        self.measurements = []
        switch name {
        case "testNilEntityFrameStillCompletesFrame":
            self.testNilEntityFrameStillCompletesFrame()
        case "testCompositionUsesNoCoreImage":
            self.testCompositionUsesNoCoreImage()
        case "testConvertedEntityTexturesAreReusedAcrossFrames":
            self.testConvertedEntityTexturesAreReusedAcrossFrames()
        default:
            self.failures.append("unknown test \(name)")
        }
        return MediaEditorFrameCompositorCaseResult(name: name, failures: self.failures, measurements: self.measurements)
    }

    func runAll() -> [MediaEditorFrameCompositorCaseResult] {
        return MediaEditorComposerSuite.testNames.map { self.run($0) }
    }

    private func fail(_ message: String) {
        self.failures.append(message)
    }

    private func makePool(width: Int, height: Int) -> CVPixelBufferPool? {
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA as NSNumber,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool)
        return pool
    }

    private func makeComposer(entities: [MediaEditorComposerEntity]) -> MediaEditorComposer {
        let originalDimensions = PixelDimensions(width: 1080, height: 1920)
        let values = chatMediaEditorValues(peerId: MediaEditorExportFixtures.peerId, originalDimensions: originalDimensions, qualityPreset: .compressedHigh)
        let dimensions = mediaEditorNonStoryCanvasSize(originalDimensions: originalDimensions)
        let composer = MediaEditorComposer(postbox: nil, values: values, dimensions: dimensions, outputDimensions: CGSize(width: 720.0, height: 1280.0), textScale: 1.0, videoDuration: nil, additionalVideoDuration: nil)
        composer.entities = entities
        return composer
    }

    private func process(_ composer: MediaEditorComposer, texture: MTLTexture, pool: CVPixelBufferPool, label: String) -> CVPixelBuffer? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: CVPixelBuffer?
        composer.process(main: .texture(texture, .zero, false, nil, 1.0, .zero), additional: [], timestamp: .zero, pool: pool, completion: { pixelBuffer in
            result = pixelBuffer
            semaphore.signal()
        })
        if semaphore.wait(timeout: .now() + 20.0) == .timedOut {
            self.fail("\(label): process did not call back")
            return nil
        }
        if result == nil {
            self.fail("\(label): process called back with nil")
        }
        return result
    }

    private func testConvertedEntityTexturesAreReusedAcrossFrames() {
        guard let device = MTLCreateSystemDefaultDevice(), let texture = loadTexture(image: UIImage(cgImage: makeCompositorPatternImage(width: 1080, height: 1920, transparentMargin: false)), device: device), let pool = self.makePool(width: 720, height: 1280) else {
            self.fail("no Metal device, input texture or pool")
            return
        }
        guard let entityBuffer = makeCompositorPixelBuffer(width: 256, height: 256), let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) else {
            self.fail("cannot create the entity pixel buffer")
            return
        }
        CVPixelBufferLockBaseAddress(entityBuffer, [])
        if let base = CVPixelBufferGetBaseAddress(entityBuffer) {
            memset(base, 200, CVPixelBufferGetBytesPerRow(entityBuffer) * 256)
        }
        CVPixelBufferUnlockBaseAddress(entityBuffer, [])
        CVBufferSetAttachment(entityBuffer, kCVImageBufferCGColorSpaceKey, colorSpace, .shouldPropagate)
        let frame = MediaEditorComposerEntityFrame(content: .pixelBuffer(entityBuffer), alphaMask: nil)
        let composer = self.makeComposer(entities: [
            MediaEditorComposerStubEntity(position: CGPoint(x: 300.0, y: 500.0), frame: frame),
            MediaEditorComposerStubEntity(position: CGPoint(x: 700.0, y: 1200.0), frame: frame)
        ])
        guard let compositor = composer.compositor else {
            self.fail("no compositor")
            return
        }
        var counts: [Int] = []
        for index in 0 ..< 6 {
            guard let _ = self.process(composer, texture: texture, pool: pool, label: "frame \(index)") else {
                return
            }
            counts.append(compositor.allocatedTextureCount)
        }
        self.measurements.append("pooled texture allocations after each frame: \(counts)")
        if counts.first == 0 {
            self.fail("the converted entity frames allocated no pooled texture, so the check measures nothing")
        }
        if counts.contains(where: { $0 != counts.first }) {
            self.fail("pooled textures were allocated after the first frame: \(counts)")
        }
    }

    private func compose(entities: [MediaEditorComposerEntity], label: String) -> MediaEditorBitmap? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            self.fail("\(label): no Metal device")
            return nil
        }
        let originalDimensions = PixelDimensions(width: 1080, height: 1920)
        let values = chatMediaEditorValues(peerId: MediaEditorExportFixtures.peerId, originalDimensions: originalDimensions, qualityPreset: .compressedHigh)
        let dimensions = mediaEditorNonStoryCanvasSize(originalDimensions: originalDimensions)
        let composer = MediaEditorComposer(postbox: nil, values: values, dimensions: dimensions, outputDimensions: CGSize(width: 720.0, height: 1280.0), textScale: 1.0, videoDuration: nil, additionalVideoDuration: nil)
        composer.entities = entities
        guard let texture = loadTexture(image: UIImage(cgImage: makeCompositorPatternImage(width: 1080, height: 1920, transparentMargin: false)), device: device) else {
            self.fail("\(label): cannot upload the input texture")
            return nil
        }
        guard let pool = self.makePool(width: 720, height: 1280) else {
            self.fail("\(label): no pixel buffer pool")
            return nil
        }
        let semaphore = DispatchSemaphore(value: 0)
        var result: CVPixelBuffer?
        var completed = false
        composer.process(main: .texture(texture, .zero, false, nil, 1.0, .zero), additional: [], timestamp: .zero, pool: pool, completion: { pixelBuffer in
            result = pixelBuffer
            completed = true
            semaphore.signal()
        })
        if semaphore.wait(timeout: .now() + 20.0) == .timedOut || !completed {
            self.fail("\(label): process did not call back")
            return nil
        }
        guard let result else {
            self.fail("\(label): process called back with nil")
            return nil
        }
        guard let image = cgImage(from: result) else {
            self.fail("\(label): cannot read the pixel buffer")
            return nil
        }
        return MediaEditorBitmap(image)
    }

    private func testNilEntityFrameStillCompletesFrame() {
        let position = CGPoint(x: 400.0, y: 700.0)
        guard let plain = self.compose(entities: [], label: "without entity"),
              let withNilFrame = self.compose(entities: [MediaEditorComposerStubEntity(position: position, frame: nil)], label: "nil entity frame"),
              let withFrame = self.compose(entities: [MediaEditorComposerStubEntity(position: position, frame: MediaEditorComposerEntityFrame(content: .image(makeCompositorCircleMaskImage(size: 256)), alphaMask: nil))], label: "entity frame") else {
            return
        }
        let nilDiff = comparePixels(withNilFrame, plain, edgeMask: nil)
        self.measurements.append("nil entity frame vs no entity: maxDelta \(nilDiff.maxDelta)")
        if nilDiff.maxDelta != 0 {
            self.fail("nil entity frame changed the frame: maxDelta \(nilDiff.maxDelta)")
        }
        let frameDiff = comparePixels(withFrame, plain, edgeMask: nil)
        self.measurements.append("entity frame vs no entity: maxDelta \(frameDiff.maxDelta), outOfToleranceShare \(frameDiff.outOfToleranceShare)")
        if frameDiff.maxDelta == 0 {
            self.fail("a stub entity with a frame left the frame unchanged, so the stub is not composed")
        }
    }

    private func testCompositionUsesNoCoreImage() {
        guard let sourcesURL = MediaEditorExportFixtures.bundle.resourceURL?.appendingPathComponent("Sources"), let enumerator = FileManager.default.enumerator(at: sourcesURL, includingPropertiesForKeys: nil) else {
            self.fail("no Sources directory in the bundle")
            return
        }
        var files: [String] = []
        var composerSource: String?
        var rendererSource: String?
        var count = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            count += 1
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                self.fail("cannot read \(url.lastPathComponent)")
                continue
            }
            if url.lastPathComponent == "MediaEditorComposer.swift" {
                composerSource = text
            }
            if url.lastPathComponent == "MediaEditorRenderer.swift" {
                rendererSource = text
            }
            if mentionsCoreImage(text) {
                files.append(url.lastPathComponent)
            }
        }
        files.sort()
        self.measurements.append("\(count) source files, CoreImage in: \(files.joined(separator: ", "))")
        if count == 0 {
            self.fail("no Swift sources found under \(sourcesURL.path)")
        }
        if files != mediaEditorComposerExpectedCoreImageFiles {
            self.fail("CoreImage files \(files), expected \(mediaEditorComposerExpectedCoreImageFiles)")
        }
        if files.contains("MediaEditorComposerEntity.swift") {
            self.fail("MediaEditorComposerEntity.swift mentions CoreImage")
        }
        guard let composerSource else {
            self.fail("no MediaEditorComposer.swift")
            return
        }
        guard let functionStart = composerSource.range(of: "func process(main:"), let body = mediaEditorBraceBlock(in: composerSource, from: functionStart.upperBound) else {
            self.fail("cannot find process(main:additional:timestamp:pool:completion:)")
            return
        }
        var remainder = composerSource
        guard let branchStart = remainder.range(of: "if self.outputsYuvBuffers {", range: body), let branch = mediaEditorBraceBlock(in: remainder, from: branchStart.lowerBound) else {
            self.fail("process has no outputsYuvBuffers branch")
            return
        }
        remainder.removeSubrange(branchStart.lowerBound ..< branch.upperBound)
        let composerLines = remainder.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed != "import CoreImage" && !trimmed.contains("yuvContext") && mentionsCoreImage(trimmed)
        }
        if !composerLines.isEmpty {
            self.fail("MediaEditorComposer.swift mentions CoreImage outside the outputsYuvBuffers branch and its context: \(composerLines.map { $0.trimmingCharacters(in: .whitespaces) })")
        }
        guard let rendererSource else {
            self.fail("no MediaEditorRenderer.swift")
            return
        }
        let rendererLines = rendererSource.components(separatedBy: "\n").filter { line in
            return mentionsCoreImage(line) && !line.contains("ciImage") && !line.contains("ciInputPass")
        }
        if !rendererLines.isEmpty {
            self.fail("MediaEditorRenderer.swift mentions CoreImage outside the preview's .ciImage input: \(rendererLines.map { $0.trimmingCharacters(in: .whitespaces) })")
        }
    }
}
