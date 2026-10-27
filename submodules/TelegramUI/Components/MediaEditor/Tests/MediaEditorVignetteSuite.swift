import Foundation
import Metal
import TelegramCore
@testable import MediaEditor

struct MediaEditorVignetteSample {
    let corner: Int
    let edge: Int
    let center: Int
    let alpha: Int
}

final class MediaEditorVignetteSuite {
    static let testNames = [
        "testPositiveVignetteIsUnchanged",
        "testZeroVignetteIsIdentity",
        "testNegativeVignetteLightensEdges",
        "testNegativeVignetteMirrorsPositive"
    ]

    private static let side = 64

    private var failures: [String] = []
    private var measurements: [String] = []

    func run(_ name: String) -> MediaEditorFrameCompositorCaseResult {
        self.failures = []
        self.measurements = []
        switch name {
        case "testPositiveVignetteIsUnchanged":
            self.testPositiveVignetteIsUnchanged()
        case "testZeroVignetteIsIdentity":
            self.testZeroVignetteIsIdentity()
        case "testNegativeVignetteLightensEdges":
            self.testNegativeVignetteLightensEdges()
        case "testNegativeVignetteMirrorsPositive":
            self.testNegativeVignetteMirrorsPositive()
        default:
            self.failures.append("unknown test \(name)")
        }
        return MediaEditorFrameCompositorCaseResult(name: name, failures: self.failures, measurements: self.measurements)
    }

    func runAll() -> [MediaEditorFrameCompositorCaseResult] {
        return MediaEditorVignetteSuite.testNames.map { self.run($0) }
    }

    private func check(_ condition: Bool, _ message: String) {
        if !condition {
            self.failures.append(message)
        }
    }

    private func render(_ value: Float, gray: UInt8) -> MediaEditorVignetteSample? {
        let side = MediaEditorVignetteSuite.side
        guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue() else {
            self.failures.append("no Metal device")
            return nil
        }
        guard let path = Bundle(for: MediaEditorRenderer.self).path(forResource: "MediaEditorBundle", ofType: "bundle"), let bundle = Bundle(path: path), let library = try? device.makeDefaultLibrary(bundle: bundle) else {
            self.failures.append("no MediaEditor shader library")
            return nil
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: side, height: side, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        descriptor.storageMode = .shared
        guard let input = device.makeTexture(descriptor: descriptor), let output = device.makeTexture(descriptor: descriptor) else {
            self.failures.append("cannot make textures")
            return nil
        }
        var pixels = [UInt8](repeating: 255, count: side * side * 4)
        for index in 0 ..< side * side {
            pixels[index * 4 + 0] = gray
            pixels[index * 4 + 1] = gray
            pixels[index * 4 + 2] = gray
        }
        input.replace(region: MTLRegionMake2D(0, 0, side, side), mipmapLevel: 0, withBytes: pixels, bytesPerRow: side * 4)

        let values = chatMediaEditorValues(peerId: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1)), originalDimensions: PixelDimensions(width: Int32(side), height: Int32(side)), qualityPreset: .compressedHigh).withUpdatedToolValues([.vignette: value])
        let chain = MediaEditorRenderChain()
        chain.adjustmentsPass.setup(device: device, library: library)
        chain.update(values: values)
        guard let commandBuffer = commandQueue.makeCommandBuffer(), let result = chain.adjustmentsPass.process(input: input, device: device, commandBuffer: commandBuffer), let blit = commandBuffer.makeBlitCommandEncoder() else {
            self.failures.append("cannot encode the adjustments pass")
            return nil
        }
        blit.copy(from: result, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: side, height: side, depth: 1), to: output, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        var rendered = [UInt8](repeating: 0, count: side * side * 4)
        output.getBytes(&rendered, bytesPerRow: side * 4, from: MTLRegionMake2D(0, 0, side, side), mipmapLevel: 0)
        func channel(_ x: Int, _ y: Int, _ index: Int) -> Int {
            return Int(rendered[(y * side + x) * 4 + index])
        }
        let sample = MediaEditorVignetteSample(corner: channel(0, 0, 0), edge: channel(0, side / 2, 0), center: channel(side / 2, side / 2, 0), alpha: channel(0, 0, 3))
        self.measurements.append("vignette \(value) gray \(gray): corner \(sample.corner) edge \(sample.edge) center \(sample.center) alpha \(sample.alpha)")
        return sample
    }

    private func testPositiveVignetteIsUnchanged() {
        let expected: [(Float, UInt8, Int, Int)] = [
            (1.0, 128, 38, 86),
            (0.5, 128, 91, 111),
            (1.0, 64, 8, 32),
            (1.0, 192, 94, 154)
        ]
        for (value, gray, corner, edge) in expected {
            guard let sample = self.render(value, gray: gray) else {
                return
            }
            self.check(sample.corner == corner, "vignette \(value) gray \(gray): corner \(sample.corner), expected \(corner)")
            self.check(sample.edge == edge, "vignette \(value) gray \(gray): edge \(sample.edge), expected \(edge)")
        }
    }

    private func testZeroVignetteIsIdentity() {
        guard let sample = self.render(0.0, gray: 128) else {
            return
        }
        self.check(sample.corner == 128 && sample.edge == 128 && sample.center == 128, "zero vignette changed the image")
    }

    private func testNegativeVignetteLightensEdges() {
        guard let full = self.render(-1.0, gray: 128), let half = self.render(-0.5, gray: 128) else {
            return
        }
        self.check(full.corner > half.corner, "-1.0 corner \(full.corner) is not lighter than -0.5 corner \(half.corner)")
        self.check(half.corner > 128, "-0.5 corner \(half.corner) is not lighter than the source")
        self.check(full.corner > full.edge, "-1.0 corner \(full.corner) is not lighter than its edge \(full.edge)")
        self.check(full.edge > 128, "-1.0 edge \(full.edge) is not lighter than the source")
        self.check(abs(full.center - 128) <= 2, "-1.0 centre \(full.center) moved")
        self.check(full.alpha == 255, "-1.0 alpha \(full.alpha) changed")
    }

    private func testNegativeVignetteMirrorsPositive() {
        for gray: UInt8 in [64, 128, 192] {
            guard let positive = self.render(1.0, gray: 255 - gray), let negative = self.render(-1.0, gray: gray) else {
                return
            }
            self.check(abs(negative.corner - (255 - positive.corner)) <= 2, "gray \(gray): -1.0 corner \(negative.corner) does not mirror +1.0 corner \(positive.corner)")
            self.check(abs(negative.edge - (255 - positive.edge)) <= 2, "gray \(gray): -1.0 edge \(negative.edge) does not mirror +1.0 edge \(positive.edge)")
        }
    }
}
