import Foundation
import UIKit
import Metal
import CoreImage
import CoreVideo
@testable import MediaEditor

private let compositorOutputWidth = 1080
private let compositorOutputHeight = 1920
private let compositorColorSpace = CGColorSpaceCreateDeviceRGB()

struct MediaEditorFrameCompositorCaseResult {
    let name: String
    let failures: [String]
    let measurements: [String]
}

func makeCompositorPixelBuffer(width: Int, height: Int, pixelFormat: OSType = kCVPixelFormatType_32BGRA) -> CVPixelBuffer? {
    let attributes: [String: Any] = [
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
        kCVPixelBufferMetalCompatibilityKey as String: true
    ]
    var pixelBuffer: CVPixelBuffer?
    guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormat, attributes as CFDictionary, &pixelBuffer) == kCVReturnSuccess, let pixelBuffer else {
        return nil
    }
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    if CVPixelBufferIsPlanar(pixelBuffer) {
        for plane in 0 ..< CVPixelBufferGetPlaneCount(pixelBuffer) {
            if let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, plane) {
                memset(base, 0, CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane) * CVPixelBufferGetHeightOfPlane(pixelBuffer, plane))
            }
        }
    } else if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
        memset(base, 0, CVPixelBufferGetBytesPerRow(pixelBuffer) * height)
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    return pixelBuffer
}

func makeCompositorPatternImage(width: Int, height: Int, transparentMargin: Bool) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: compositorColorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)!
    let w = CGFloat(width)
    let h = CGFloat(height)
    let body = transparentMargin ? CGRect(x: w * 0.08, y: h * 0.08, width: w * 0.84, height: h * 0.84) : CGRect(x: 0.0, y: 0.0, width: w, height: h)
    context.saveGState()
    context.clip(to: body)
    let gradient = CGGradient(colorsSpace: compositorColorSpace, colors: [UIColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 1.0).cgColor, UIColor(red: 0.1, green: 0.4, blue: 0.95, alpha: 1.0).cgColor, UIColor(red: 0.2, green: 0.85, blue: 0.3, alpha: 1.0).cgColor] as CFArray, locations: [0.0, 0.5, 1.0])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: w, y: h), options: [])
    context.restoreGState()
    context.setFillColor(UIColor(red: 1.0, green: 0.95, blue: 0.2, alpha: 1.0).cgColor)
    context.fillEllipse(in: CGRect(x: w * 0.15, y: h * 0.55, width: w * 0.3, height: w * 0.3))
    context.setFillColor(UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5).cgColor)
    context.fill(CGRect(x: w * 0.55, y: h * 0.15, width: w * 0.3, height: h * 0.3))
    context.setFillColor(UIColor(white: 1.0, alpha: 0.35).cgColor)
    context.fillEllipse(in: CGRect(x: w * 0.02, y: h * 0.02, width: w * 0.2, height: w * 0.2))
    context.setFillColor(UIColor.white.cgColor)
    for i in 0 ..< 6 {
        context.fill(CGRect(x: w * 0.12 + CGFloat(i) * w * 0.05, y: h * 0.25, width: w * 0.02, height: h * 0.2))
    }
    return context.makeImage()!
}

func makeCompositorCircleMaskImage(size: Int) -> CGImage {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: compositorColorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)!
    context.setFillColor(UIColor.white.cgColor)
    context.fillEllipse(in: CGRect(x: 0.0, y: 0.0, width: CGFloat(size), height: CGFloat(size)))
    return context.makeImage()!
}

func makeCompositorRoundedMaskImage(size: Int) -> CGImage {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: compositorColorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)!
    let rect = CGRect(x: 0.0, y: 0.0, width: CGFloat(size), height: CGFloat(size))
    context.setFillColor(UIColor.black.cgColor)
    context.fill(rect)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width / 8.0, cornerHeight: rect.height / 8.0, transform: nil))
    context.setFillColor(UIColor.white.cgColor)
    context.fillPath()
    return context.makeImage()!
}

final class MediaEditorFrameCompositorSuite {
    static let testNames: [String] = [
        "testIdentityLayerMatchesSource",
        "testRotatedScaledLayerMatchesCoreImage",
        "testLayerSampledOutsideTextureIsTransparent",
        "testLayerOutsideOutputIsClipped",
        "testAlphaMaskMatchesBlendWithAlphaMask",
        "testFinalMaskMatchesBlendWithMask",
        "testBottomLeftOriginLayerIsFlipped",
        "testYuvPixelBufferTextureMatchesCoreImage"
    ]

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
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: compositorColorSpace])
    }

    func run(_ name: String) -> MediaEditorFrameCompositorCaseResult {
        self.failures = []
        self.measurements = []
        switch name {
        case "testIdentityLayerMatchesSource":
            self.testIdentityLayerMatchesSource()
        case "testRotatedScaledLayerMatchesCoreImage":
            self.testRotatedScaledLayerMatchesCoreImage()
        case "testLayerSampledOutsideTextureIsTransparent":
            self.testLayerSampledOutsideTextureIsTransparent()
        case "testLayerOutsideOutputIsClipped":
            self.testLayerOutsideOutputIsClipped()
        case "testAlphaMaskMatchesBlendWithAlphaMask":
            self.testAlphaMaskMatchesBlendWithAlphaMask()
        case "testFinalMaskMatchesBlendWithMask":
            self.testFinalMaskMatchesBlendWithMask()
        case "testBottomLeftOriginLayerIsFlipped":
            self.testBottomLeftOriginLayerIsFlipped()
        case "testYuvPixelBufferTextureMatchesCoreImage":
            self.testYuvPixelBufferTextureMatchesCoreImage()
        default:
            self.fail("unknown test \(name)")
        }
        return MediaEditorFrameCompositorCaseResult(name: name, failures: self.failures, measurements: self.measurements)
    }

    func runAll() -> [MediaEditorFrameCompositorCaseResult] {
        return MediaEditorFrameCompositorSuite.testNames.map { self.run($0) }
    }

    private func fail(_ message: String) {
        self.failures.append(message)
    }

    private var outputSize: CGSize {
        return CGSize(width: compositorOutputWidth, height: compositorOutputHeight)
    }

    private func renderMetal(_ scene: MediaEditorCompositionScene) -> MediaEditorBitmap? {
        guard let pixelBuffer = makeCompositorPixelBuffer(width: Int(scene.outputSize.width), height: Int(scene.outputSize.height)) else {
            self.fail("cannot create the Metal output buffer")
            return nil
        }
        guard self.compositor.render(scene: scene, into: pixelBuffer) else {
            self.fail("compositor render returned false")
            return nil
        }
        guard let image = cgImage(from: pixelBuffer) else {
            self.fail("cannot read the Metal output buffer")
            return nil
        }
        return MediaEditorBitmap(image)
    }

    private func renderCoreImage(_ image: CIImage, size: CGSize? = nil) -> MediaEditorBitmap? {
        let size = size ?? self.outputSize
        guard let pixelBuffer = makeCompositorPixelBuffer(width: Int(size.width), height: Int(size.height)) else {
            self.fail("cannot create the CoreImage output buffer")
            return nil
        }
        self.ciContext.render(image, to: pixelBuffer)
        guard let result = cgImage(from: pixelBuffer) else {
            self.fail("cannot read the CoreImage output buffer")
            return nil
        }
        return MediaEditorBitmap(result)
    }

    private func ciImage(_ image: CGImage) -> CIImage {
        return CIImage(cgImage: image, options: [.colorSpace: compositorColorSpace])
    }

    private func texture(_ image: CGImage) -> MTLTexture? {
        guard let texture = self.compositor.texture(for: image) else {
            self.fail("cannot create a texture for a \(image.width)x\(image.height) image")
            return nil
        }
        return texture
    }

    private func black() -> SIMD4<Float> {
        return SIMD4<Float>(0.0, 0.0, 0.0, 1.0)
    }

    private func blackCIImage() -> CIImage {
        return CIImage(color: CIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)).cropped(to: CGRect(origin: .zero, size: self.outputSize))
    }

    private func rotatedScaledTransform() -> CGAffineTransform {
        return CGAffineTransform(scaleX: 1.37, y: 1.37).concatenating(CGAffineTransform(rotationAngle: 0.7)).concatenating(CGAffineTransform(translationX: 311.5, y: 902.25))
    }

    @discardableResult
    private func compare(_ label: String, _ metal: MediaEditorBitmap, _ reference: MediaEditorBitmap, maxDelta allowedMaxDelta: Int? = nil, maxNonEdgeDelta allowedNonEdgeDelta: Int? = nil, meanDelta allowedMeanDelta: Double? = nil) -> PixelDiff {
        let diff = comparePixels(metal, reference, edgeMask: edgeMask(for: reference))
        self.measurements.append("\(label): maxDelta=\(diff.maxDelta) maxNonEdgeDelta=\(diff.maxNonEdgeDelta) meanDelta=(\(String(format: "%.4f, %.4f, %.4f, %.4f", diff.meanDelta.x, diff.meanDelta.y, diff.meanDelta.z, diff.meanDelta.w))) outOfToleranceShare=\(String(format: "%.6f", diff.outOfToleranceShare)) edgeShare=\(String(format: "%.6f", diff.edgeShare))")
        if let allowedMaxDelta, diff.maxDelta > allowedMaxDelta {
            self.fail("\(label): maxDelta \(diff.maxDelta) > \(allowedMaxDelta)")
        }
        if let allowedNonEdgeDelta, diff.maxNonEdgeDelta > allowedNonEdgeDelta {
            self.fail("\(label): maxNonEdgeDelta \(diff.maxNonEdgeDelta) > \(allowedNonEdgeDelta)")
        }
        if let allowedMeanDelta, diff.meanDelta.max() > allowedMeanDelta {
            self.fail("\(label): meanDelta \(diff.meanDelta) > \(allowedMeanDelta)")
        }
        return diff
    }

    private func testIdentityLayerMatchesSource() {
        let image = makeCompositorPatternImage(width: compositorOutputWidth, height: compositorOutputHeight, transparentMargin: true)
        guard let texture = self.texture(image) else {
            return
        }
        let scene = MediaEditorCompositionScene(outputSize: self.outputSize, background: nil, backgroundRect: .zero, layers: [MediaEditorCompositionLayer(texture: texture, origin: .topLeft, transform: .identity, alphaMask: nil)], finalMask: nil)
        guard let metal = self.renderMetal(scene) else {
            return
        }
        self.compare("identity vs source", metal, MediaEditorBitmap(image), maxDelta: 0)
    }

    private func testRotatedScaledLayerMatchesCoreImage() {
        let image = makeCompositorPatternImage(width: 600, height: 400, transparentMargin: true)
        guard let texture = self.texture(image) else {
            return
        }
        let transform = self.rotatedScaledTransform()
        let scene = MediaEditorCompositionScene(outputSize: self.outputSize, background: self.black(), backgroundRect: CGRect(origin: .zero, size: self.outputSize), layers: [MediaEditorCompositionLayer(texture: texture, origin: .topLeft, transform: transform, alphaMask: nil)], finalMask: nil)
        let reference = self.ciImage(image).samplingLinear().transformed(by: transform).composited(over: self.blackCIImage())
        guard let metal = self.renderMetal(scene), let coreImage = self.renderCoreImage(reference) else {
            return
        }
        self.compare("rotated scaled vs CoreImage", metal, coreImage, maxNonEdgeDelta: pixelDiffTolerance, meanDelta: 0.5)
    }

    private func testLayerSampledOutsideTextureIsTransparent() {
        let context = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 64 * 4, space: compositorColorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)!
        context.setFillColor(UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0).cgColor)
        context.fill(CGRect(x: 0.0, y: 0.0, width: 64.0, height: 64.0))
        let image = context.makeImage()!
        guard let texture = self.texture(image) else {
            return
        }
        let origin = CGPoint(x: 200.0, y: 600.0)
        let transform = CGAffineTransform(scaleX: 8.0, y: 8.0).concatenating(CGAffineTransform(translationX: origin.x, y: origin.y))
        let scene = MediaEditorCompositionScene(outputSize: self.outputSize, background: nil, backgroundRect: .zero, layers: [MediaEditorCompositionLayer(texture: texture, origin: .topLeft, transform: transform, alphaMask: nil)], finalMask: nil)
        guard let metal = self.renderMetal(scene) else {
            return
        }
        let scaledRect = CGRect(x: origin.x, y: origin.y, width: 512.0, height: 512.0)
        let allowedRect = scaledRect.insetBy(dx: -9.0, dy: -9.0)
        var nonClear = 0
        var interiorWrong = 0
        let height = metal.height
        for row in 0 ..< height {
            let y = CGFloat(height - row) - 0.5
            for x in 0 ..< metal.width {
                let point = CGPoint(x: CGFloat(x) + 0.5, y: y)
                let offset = (row * metal.width + x) * 4
                if !allowedRect.contains(point) {
                    if metal.bytes[offset] != 0 || metal.bytes[offset + 1] != 0 || metal.bytes[offset + 2] != 0 || metal.bytes[offset + 3] != 0 {
                        nonClear += 1
                    }
                } else if scaledRect.insetBy(dx: 9.0, dy: 9.0).contains(point) {
                    if metal.bytes[offset] != 0 || metal.bytes[offset + 1] != 0 || metal.bytes[offset + 2] != 255 || metal.bytes[offset + 3] != 255 {
                        interiorWrong += 1
                    }
                }
            }
        }
        self.measurements.append("pixels farther than 9 px outside the scaled rect that are not clear: \(nonClear); interior pixels that are not opaque red: \(interiorWrong)")
        if nonClear != 0 {
            self.fail("\(nonClear) pixels farther than 9 px outside the scaled rect are not (0,0,0,0)")
        }
        if interiorWrong != 0 {
            self.fail("\(interiorWrong) interior pixels are not opaque red")
        }
        let reference = self.ciImage(image).samplingLinear().transformed(by: transform)
        if let coreImage = self.renderCoreImage(reference) {
            self.compare("8x scaled vs CoreImage", metal, coreImage, maxNonEdgeDelta: pixelDiffTolerance, meanDelta: 0.5)
        }
        let edgeCases: [(String, CGAffineTransform)] = [
            ("8x at a half-pixel offset", CGAffineTransform(scaleX: 8.0, y: 8.0).concatenating(CGAffineTransform(translationX: 200.5, y: 600.25))),
            ("1.5x at an integral offset", CGAffineTransform(scaleX: 1.5, y: 1.5).concatenating(CGAffineTransform(translationX: 200.0, y: 600.0))),
            ("0.5x at an integral offset", CGAffineTransform(scaleX: 0.5, y: 0.5).concatenating(CGAffineTransform(translationX: 200.0, y: 600.0))),
            ("8x rotated by 90 degrees", CGAffineTransform(scaleX: 8.0, y: 8.0).concatenating(CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)).concatenating(CGAffineTransform(translationX: 712.0, y: 600.0))),
            ("8x rotated by 0.01 rad", CGAffineTransform(scaleX: 8.0, y: 8.0).concatenating(CGAffineTransform(translationX: -256.0, y: -256.0)).concatenating(CGAffineTransform(rotationAngle: 0.01)).concatenating(CGAffineTransform(translationX: 540.0, y: 960.0)))
        ]
        for (label, edgeTransform) in edgeCases {
            let edgeScene = MediaEditorCompositionScene(outputSize: self.outputSize, background: nil, backgroundRect: .zero, layers: [MediaEditorCompositionLayer(texture: texture, origin: .topLeft, transform: edgeTransform, alphaMask: nil)], finalMask: nil)
            guard let edgeMetal = self.renderMetal(edgeScene), let edgeCoreImage = self.renderCoreImage(self.ciImage(image).samplingLinear().transformed(by: edgeTransform)) else {
                continue
            }
            self.compare("\(label) vs CoreImage", edgeMetal, edgeCoreImage, maxNonEdgeDelta: pixelDiffTolerance, meanDelta: 0.5)
        }
    }

    private func testLayerOutsideOutputIsClipped() {
        let image = makeCompositorPatternImage(width: 1000, height: 1000, transparentMargin: false)
        guard let texture = self.texture(image) else {
            return
        }
        let background = SIMD4<Float>(0.2, 0.4, 0.6, 1.0)
        let transform = CGAffineTransform(translationX: -500.0, y: -500.0)
        let scene = MediaEditorCompositionScene(outputSize: self.outputSize, background: background, backgroundRect: CGRect(origin: .zero, size: self.outputSize), layers: [MediaEditorCompositionLayer(texture: texture, origin: .topLeft, transform: transform, alphaMask: nil)], finalMask: nil)
        guard let metal = self.renderMetal(scene) else {
            return
        }
        if metal.width != compositorOutputWidth || metal.height != compositorOutputHeight {
            self.fail("output size \(metal.width)x\(metal.height)")
        }
        let expected: [UInt8] = [153, 102, 51, 255]
        var wrongBackground = 0
        for row in 0 ..< 600 {
            for x in (metal.width - 600) ..< metal.width {
                let offset = (row * metal.width + x) * 4
                for channel in 0 ..< 4 where abs(Int(metal.bytes[offset + channel]) - Int(expected[channel])) > 1 {
                    wrongBackground += 1
                    break
                }
            }
        }
        var wrongBottomRight = 0
        for row in (metal.height - 600) ..< metal.height {
            for x in 600 ..< metal.width {
                let offset = (row * metal.width + x) * 4
                for channel in 0 ..< 4 where abs(Int(metal.bytes[offset + channel]) - Int(expected[channel])) > 1 {
                    wrongBottomRight += 1
                    break
                }
            }
        }
        self.measurements.append("top-right 600x600 pixels that are not background: \(wrongBackground); bottom pixels right of the layer that are not background: \(wrongBottomRight)")
        if wrongBackground != 0 {
            self.fail("\(wrongBackground) pixels in the opposite corner are not the background")
        }
        if wrongBottomRight != 0 {
            self.fail("\(wrongBottomRight) pixels right of the clipped layer are not the background")
        }
        let reference = self.ciImage(image).samplingLinear().transformed(by: transform).composited(over: CIImage(color: CIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1.0)).cropped(to: CGRect(origin: .zero, size: self.outputSize)))
        if let coreImage = self.renderCoreImage(reference) {
            self.compare("clipped layer vs CoreImage", metal, coreImage, maxNonEdgeDelta: pixelDiffTolerance, meanDelta: 0.5)
        }
    }

    private func testAlphaMaskMatchesBlendWithAlphaMask() {
        let image = makeCompositorPatternImage(width: 512, height: 512, transparentMargin: false)
        let mask = makeCompositorCircleMaskImage(size: 512)
        guard let texture = self.texture(image), let maskTexture = self.texture(mask) else {
            return
        }
        let transform = self.rotatedScaledTransform()
        let scene = MediaEditorCompositionScene(outputSize: self.outputSize, background: self.black(), backgroundRect: CGRect(origin: .zero, size: self.outputSize), layers: [MediaEditorCompositionLayer(texture: texture, origin: .topLeft, transform: transform, alphaMask: maskTexture)], finalMask: nil)
        guard let filter = CIFilter(name: "CIBlendWithAlphaMask") else {
            self.fail("no CIBlendWithAlphaMask")
            return
        }
        filter.setValue(self.ciImage(image), forKey: kCIInputImageKey)
        filter.setValue(CIImage(cgImage: mask), forKey: kCIInputMaskImageKey)
        guard let masked = filter.outputImage else {
            self.fail("CIBlendWithAlphaMask has no output")
            return
        }
        let reference = masked.samplingLinear().transformed(by: transform).composited(over: self.blackCIImage())
        guard let metal = self.renderMetal(scene), let coreImage = self.renderCoreImage(reference) else {
            return
        }
        self.compare("alpha mask vs CIBlendWithAlphaMask", metal, coreImage, maxNonEdgeDelta: pixelDiffTolerance, meanDelta: 0.5)
    }

    private func testFinalMaskMatchesBlendWithMask() {
        let image = makeCompositorPatternImage(width: compositorOutputWidth, height: compositorOutputHeight, transparentMargin: false)
        let sticker = makeCompositorPatternImage(width: 600, height: 400, transparentMargin: true)
        let maskSize = Int(floor(1080.0 * 0.97))
        let mask = makeCompositorRoundedMaskImage(size: maskSize)
        guard let texture = self.texture(image), let stickerTexture = self.texture(sticker), let maskTexture = self.texture(mask) else {
            return
        }
        let stickerTransform = self.rotatedScaledTransform()
        let maskTransform = CGAffineTransform(translationX: 16.0, y: 436.0)
        let scene = MediaEditorCompositionScene(outputSize: self.outputSize, background: self.black(), backgroundRect: CGRect(origin: .zero, size: self.outputSize), layers: [
            MediaEditorCompositionLayer(texture: texture, origin: .topLeft, transform: .identity, alphaMask: nil),
            MediaEditorCompositionLayer(texture: stickerTexture, origin: .topLeft, transform: stickerTransform, alphaMask: nil)
        ], finalMask: (maskTexture, maskTransform))
        let composite = self.ciImage(sticker).samplingLinear().transformed(by: stickerTransform).composited(over: self.ciImage(image).samplingLinear().composited(over: self.blackCIImage()))
        guard let filter = CIFilter(name: "CIBlendWithMask") else {
            self.fail("no CIBlendWithMask")
            return
        }
        filter.setValue(composite, forKey: kCIInputImageKey)
        filter.setValue(CIImage(cgImage: mask).transformed(by: maskTransform), forKey: kCIInputMaskImageKey)
        filter.setValue(CIImage(color: .clear), forKey: kCIInputBackgroundImageKey)
        guard let blended = filter.outputImage else {
            self.fail("CIBlendWithMask has no output")
            return
        }
        let reference = blended.cropped(to: composite.extent)
        guard let metal = self.renderMetal(scene), let coreImage = self.renderCoreImage(reference) else {
            return
        }
        self.compare("final mask vs CIBlendWithMask", metal, coreImage, maxNonEdgeDelta: pixelDiffTolerance, meanDelta: 0.5)
    }

    private func testBottomLeftOriginLayerIsFlipped() {
        let image = makeCompositorPatternImage(width: compositorOutputWidth, height: compositorOutputHeight, transparentMargin: true)
        guard let texture = self.texture(image) else {
            return
        }
        let scene = MediaEditorCompositionScene(outputSize: self.outputSize, background: nil, backgroundRect: .zero, layers: [MediaEditorCompositionLayer(texture: texture, origin: .bottomLeft, transform: .identity, alphaMask: nil)], finalMask: nil)
        guard let reference = CIImage(mtlTexture: texture, options: [.colorSpace: compositorColorSpace]) else {
            self.fail("CIImage(mtlTexture:) failed")
            return
        }
        guard let metal = self.renderMetal(scene), let coreImage = self.renderCoreImage(reference) else {
            return
        }
        self.compare("bottom-left origin vs CIImage(mtlTexture:)", metal, coreImage, maxNonEdgeDelta: pixelDiffTolerance, meanDelta: 0.5)
        let source = MediaEditorBitmap(image)
        let rowBytes = source.width * 4
        let firstRow = Array(source.bytes[0 ..< rowBytes])
        let lastOutputRow = Array(metal.bytes[(metal.height - 1) * rowBytes ..< metal.height * rowBytes])
        if firstRow != lastOutputRow {
            self.fail("texture row 0 is not the bottom output row")
        }
    }

    private func makeYuvPixelBuffer(pixelFormat: OSType, matrix: CFString?) -> CVPixelBuffer? {
        guard let pixelBuffer = makeCompositorPixelBuffer(width: compositorOutputWidth, height: compositorOutputHeight, pixelFormat: pixelFormat) else {
            return nil
        }
        let isVideoRange = pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let yBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)!.assumingMemoryBound(to: UInt8.self)
        let yStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let cBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)!.assumingMemoryBound(to: UInt8.self)
        let cStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
        let width = compositorOutputWidth
        let height = compositorOutputHeight
        for row in 0 ..< height {
            for x in 0 ..< width {
                let fx = Double(x) / Double(width)
                let fy = Double(row) / Double(height)
                let luma = 0.5 + 0.35 * sin(fx * 6.0 + fy * 3.0) + 0.1 * cos(fy * 11.0)
                let value = isVideoRange ? 16.0 + luma * 219.0 : luma * 255.0
                yBase[row * yStride + x] = UInt8(max(0.0, min(255.0, value.rounded())))
            }
        }
        for row in 0 ..< height / 2 {
            for x in 0 ..< width / 2 {
                let fx = Double(x) / Double(width / 2)
                let fy = Double(row) / Double(height / 2)
                let cb = 0.3 * sin(fx * 4.0 + 1.0) * cos(fy * 2.0)
                let cr = 0.3 * cos(fx * 3.0) * sin(fy * 5.0 + 0.5)
                let scale = isVideoRange ? 224.0 : 255.0
                cBase[row * cStride + x * 2] = UInt8(max(0.0, min(255.0, (128.0 + cb * scale).rounded())))
                cBase[row * cStride + x * 2 + 1] = UInt8(max(0.0, min(255.0, (128.0 + cr * scale).rounded())))
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        if let matrix {
            CVBufferSetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, matrix, .shouldPropagate)
        }
        return pixelBuffer
    }

    private func testYuvPixelBufferTextureMatchesCoreImage() {
        let variants: [(String, OSType, CFString?)] = [
            ("420f BT.709", kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVImageBufferYCbCrMatrix_ITU_R_709_2),
            ("420f BT.601", kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVImageBufferYCbCrMatrix_ITU_R_601_4),
            ("420f no matrix", kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, nil),
            ("420v BT.709", kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVImageBufferYCbCrMatrix_ITU_R_709_2)
        ]
        for (label, pixelFormat, matrix) in variants {
            guard let pixelBuffer = self.makeYuvPixelBuffer(pixelFormat: pixelFormat, matrix: matrix) else {
                self.fail("\(label): cannot create the YUV buffer")
                continue
            }
            guard let texture = self.compositor.texture(for: pixelBuffer, convertingTo: nil) else {
                self.fail("\(label): no texture for the YUV buffer")
                continue
            }
            let scene = MediaEditorCompositionScene(outputSize: self.outputSize, background: nil, backgroundRect: .zero, layers: [MediaEditorCompositionLayer(texture: texture, origin: .topLeft, transform: .identity, alphaMask: nil)], finalMask: nil)
            guard let metal = self.renderMetal(scene), let coreImage = self.renderCoreImage(CIImage(cvPixelBuffer: pixelBuffer)) else {
                continue
            }
            self.compare("\(label) vs CIImage(cvPixelBuffer:)", metal, coreImage, maxDelta: pixelDiffTolerance)
        }
    }
}
