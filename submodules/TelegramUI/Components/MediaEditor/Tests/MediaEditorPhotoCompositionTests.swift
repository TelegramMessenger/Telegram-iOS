import Foundation
import UIKit
import Metal
import CoreMedia
import CoreImage
import TelegramCore
@testable import MediaEditor

private struct PhotoTestColor: Equatable {
    let r: Int
    let g: Int
    let b: Int
    let a: Int

    static let red = PhotoTestColor(r: 255, g: 0, b: 0, a: 255)
    static let green = PhotoTestColor(r: 0, g: 255, b: 0, a: 255)
    static let blue = PhotoTestColor(r: 0, g: 0, b: 255, a: 255)
    static let yellow = PhotoTestColor(r: 255, g: 255, b: 0, a: 255)
    static let white = PhotoTestColor(r: 255, g: 255, b: 255, a: 255)
    static let magenta = PhotoTestColor(r: 255, g: 0, b: 255, a: 255)

    func isClose(to other: PhotoTestColor, tolerance: Int = 24) -> Bool {
        return abs(self.r - other.r) <= tolerance && abs(self.g - other.g) <= tolerance && abs(self.b - other.b) <= tolerance && abs(self.a - other.a) <= tolerance
    }
}

private let photoQuadrantTopLeft = PhotoTestColor.red
private let photoQuadrantTopRight = PhotoTestColor.green
private let photoQuadrantBottomLeft = PhotoTestColor.blue
private let photoQuadrantBottomRight = PhotoTestColor.yellow

private func photoTestImage(size: CGSize, opaque: Bool, draw: (CGContext) -> Void) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    format.opaque = opaque
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
        draw(context.cgContext)
    }
}

private func photoQuadrantImage(width: CGFloat = 400.0, height: CGFloat = 300.0) -> UIImage {
    return photoTestImage(size: CGSize(width: width, height: height), opaque: true) { context in
        let halfWidth = width / 2.0
        let halfHeight = height / 2.0
        context.setFillColor(UIColor.red.cgColor)
        context.fill(CGRect(x: 0.0, y: 0.0, width: halfWidth, height: halfHeight))
        context.setFillColor(UIColor.green.cgColor)
        context.fill(CGRect(x: halfWidth, y: 0.0, width: halfWidth, height: halfHeight))
        context.setFillColor(UIColor.blue.cgColor)
        context.fill(CGRect(x: 0.0, y: halfHeight, width: halfWidth, height: halfHeight))
        context.setFillColor(UIColor.yellow.cgColor)
        context.fill(CGRect(x: halfWidth, y: halfHeight, width: halfWidth, height: halfHeight))
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: halfWidth - 10.0, y: halfHeight - 10.0, width: 20.0, height: 20.0))
    }
}

private final class PhotoPixelSampler {
    let width: Int
    let height: Int
    private let data: [UInt8]

    init(_ image: UIImage) {
        let cgImage = image.cgImage!
        let width = cgImage.width
        let height = cgImage.height
        self.width = width
        self.height = height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        data.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        self.data = data
    }

    func color(x: CGFloat, y: CGFloat) -> PhotoTestColor {
        let px = max(0, min(self.width - 1, Int(x)))
        let py = max(0, min(self.height - 1, Int(y)))
        let offset = (py * self.width + px) * 4
        return PhotoTestColor(r: Int(self.data[offset]), g: Int(self.data[offset + 1]), b: Int(self.data[offset + 2]), a: Int(self.data[offset + 3]))
    }

    func color(fx: CGFloat, fy: CGFloat) -> PhotoTestColor {
        return self.color(x: fx * CGFloat(self.width), y: fy * CGFloat(self.height))
    }
}

private func photoRotatedSize(_ size: CGSize, rotation: CGFloat) -> CGSize {
    var transform = CGAffineTransform(translationX: size.width / 2.0, y: size.height / 2.0)
    transform = transform.rotated(by: rotation)
    transform = transform.translatedBy(x: -size.width / 2.0, y: -size.height / 2.0)
    return CGRect(origin: .zero, size: size).applying(transform).size
}

private let photoPerspectiveMarkers: [(point: CGPoint, color: PhotoTestColor)] = [
    (CGPoint(x: 0.15, y: 0.17), .red),
    (CGPoint(x: 0.85, y: 0.18), .green),
    (CGPoint(x: 0.84, y: 0.84), .blue),
    (CGPoint(x: 0.16, y: 0.82), .magenta)
]

private func photoPerspectiveMarkerImage(width: CGFloat = 400.0, height: CGFloat = 300.0) -> UIImage {
    return photoTestImage(size: CGSize(width: width, height: height), opaque: true) { context in
        context.setFillColor(UIColor(white: 0.5, alpha: 1.0).cgColor)
        context.fill(CGRect(x: 0.0, y: 0.0, width: width, height: height))
        for marker in photoPerspectiveMarkers {
            context.setFillColor(UIColor(red: CGFloat(marker.color.r) / 255.0, green: CGFloat(marker.color.g) / 255.0, blue: CGFloat(marker.color.b) / 255.0, alpha: 1.0).cgColor)
            context.fill(CGRect(x: marker.point.x * width - 6.0, y: marker.point.y * height - 6.0, width: 12.0, height: 12.0))
        }
    }
}

private func photoPerspectiveExpectedPoint(_ point: CGPoint, original: CGSize, values: MediaEditorValues, cropRect: CGRect) -> CGPoint {
    var centered = CGPoint(x: point.x - original.width / 2.0, y: point.y - original.height / 2.0)
    if values.cropMirroring {
        centered.x = -centered.x
    }
    centered = MediaEditorPerspectiveHomography(perspective: values.cropPerspective, size: original).apply(centered)
    let angle = values.cropRotation
    let rotated = CGPoint(x: centered.x * cos(angle) - centered.y * sin(angle), y: centered.x * sin(angle) + centered.y * cos(angle))
    let rotatedSize = photoRotatedSize(original, rotation: angle)
    let unrotated = CGPoint(x: rotated.x + rotatedSize.width / 2.0 - cropRect.minX, y: rotated.y + rotatedSize.height / 2.0 - cropRect.minY)
    let width = cropRect.width
    let height = cropRect.height
    switch values.cropOrientation ?? .up {
    case .up:
        return CGPoint(x: unrotated.x / width, y: unrotated.y / height)
    case .down:
        return CGPoint(x: (width - unrotated.x) / width, y: (height - unrotated.y) / height)
    case .left:
        return CGPoint(x: unrotated.y / height, y: (width - unrotated.x) / width)
    case .right:
        return CGPoint(x: (height - unrotated.y) / height, y: unrotated.x / width)
    }
}

final class MediaEditorPhotoCompositionSuite {
    static let testNames = [
        "testReadbackMatchesCoreImage",
        "testPanoramaPhotoComposes",
        "testOversizedPhotoIsDownscaledBeforeUpload",
        "testEditorResultMatchesImageInput",
        "testIdentityUnchanged",
        "testCropRectTopLeftQuadrant",
        "testOrientationLeft",
        "testMirrorFlipsMediaOnly",
        "testRotatedCropOrientedPixels",
        "testChatCompositionRendersTightCropFromSourcePixels",
        "testOrientedOddCropEdgesAreOpaque",
        "testPerspectiveMarkersLandWhereHomographySays",
        "testPerspectiveWithOrientationAndMirror"
    ]

    private var failures: [String] = []
    private var measurements: [String] = []

    func run(_ name: String) -> MediaEditorFrameCompositorCaseResult {
        self.failures = []
        self.measurements = []
        switch name {
        case "testReadbackMatchesCoreImage":
            self.testReadbackMatchesCoreImage()
        case "testPanoramaPhotoComposes":
            self.testPanoramaPhotoComposes()
        case "testOversizedPhotoIsDownscaledBeforeUpload":
            self.testOversizedPhotoIsDownscaledBeforeUpload()
        case "testEditorResultMatchesImageInput":
            self.testEditorResultMatchesImageInput()
        case "testIdentityUnchanged":
            self.testIdentityUnchanged()
        case "testCropRectTopLeftQuadrant":
            self.testCropRectTopLeftQuadrant()
        case "testOrientationLeft":
            self.testOrientationLeft()
        case "testMirrorFlipsMediaOnly":
            self.testMirrorFlipsMediaOnly()
        case "testRotatedCropOrientedPixels":
            self.testRotatedCropOrientedPixels()
        case "testChatCompositionRendersTightCropFromSourcePixels":
            self.testChatCompositionRendersTightCropFromSourcePixels()
        case "testOrientedOddCropEdgesAreOpaque":
            self.testOrientedOddCropEdgesAreOpaque()
        case "testPerspectiveMarkersLandWhereHomographySays":
            self.testPerspectiveMarkersLandWhereHomographySays()
        case "testPerspectiveWithOrientationAndMirror":
            self.testPerspectiveWithOrientationAndMirror()
        default:
            self.failures.append("unknown test \(name)")
        }
        return MediaEditorFrameCompositorCaseResult(name: name, failures: self.failures, measurements: self.measurements)
    }

    func runAll() -> [MediaEditorFrameCompositorCaseResult] {
        return MediaEditorPhotoCompositionSuite.testNames.map { self.run($0) }
    }

    private func fail(_ message: String) {
        self.failures.append(message)
    }

    private func wait(label: String, _ start: (@escaping (UIImage?) -> Void) -> Void) -> UIImage? {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var result: UIImage?
        start { image in
            lock.lock()
            result = image
            lock.unlock()
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + 60.0) == .timedOut {
            self.fail("\(label): composition did not call back")
            return nil
        }
        lock.lock()
        defer {
            lock.unlock()
        }
        if result == nil {
            self.fail("\(label): composition returned nil")
        }
        return result
    }

    private func baseValues(width: Int32 = 400, height: Int32 = 300) -> MediaEditorValues {
        return chatMediaEditorValues(peerId: MediaEditorExportFixtures.peerId, originalDimensions: PixelDimensions(width: width, height: height), qualityPreset: .compressedHigh)
    }

    private func compose(_ values: MediaEditorValues, inputImage: UIImage = photoQuadrantImage(), label: String) -> UIImage? {
        let dimensions = mediaEditorNonStoryCanvasSize(originalDimensions: values.originalDimensions)
        return self.wait(label: label) { completion in
            makeEditorImageComposition(postbox: nil, input: .image(inputImage), dimensions: dimensions, values: values, time: .zero, textScale: 2.0, completion: completion)
        }
    }

    private func composeChat(_ values: MediaEditorValues, input: MediaEditorCompositionInput, maxOutputSide: CGFloat, label: String) -> UIImage? {
        return self.wait(label: label) { completion in
            makeChatEditorImageComposition(postbox: nil, input: input, values: values, time: .zero, maxOutputSide: maxOutputSide, completion: completion)
        }
    }

    private func assertColor(_ sampler: PhotoPixelSampler, _ fx: CGFloat, _ fy: CGFloat, _ expected: PhotoTestColor, _ label: String) {
        let actual = sampler.color(fx: fx, fy: fy)
        if !actual.isClose(to: expected) {
            self.fail("\(label): at (\(fx), \(fy)) expected \(expected), got \(actual)")
        }
    }

    private func coreImageReadback(device: MTLDevice, texture: MTLTexture, mirror: Bool) -> CGImage? {
        guard let ciImage = CIImage(mtlTexture: texture, options: [.colorSpace: CGColorSpaceCreateDeviceRGB()]) else {
            return nil
        }
        let transform: CGAffineTransform
        if mirror {
            transform = CGAffineTransform(-1.0, 0.0, 0.0, -1.0, ciImage.extent.width, ciImage.extent.height)
        } else {
            transform = CGAffineTransform(1.0, 0.0, 0.0, -1.0, 0.0, ciImage.extent.height)
        }
        let image = ciImage.transformed(by: transform)
        return CIContext(mtlDevice: device, options: [:]).createCGImage(image, from: image.extent)
    }

    private func checkReadback(device: MTLDevice, texture: MTLTexture, mirror: Bool, name: String) {
        guard let image = getTextureImage(device: device, texture: texture, mirror: mirror)?.cgImage else {
            self.fail("\(name): getTextureImage returned nil")
            return
        }
        guard let expected = self.coreImageReadback(device: device, texture: texture, mirror: mirror) else {
            self.fail("\(name): CoreImage readback returned nil")
            return
        }
        guard expected.width == image.width, expected.height == image.height else {
            self.fail("\(name): size \(image.width)x\(image.height), CoreImage \(expected.width)x\(expected.height)")
            return
        }
        let actualBitmap = MediaEditorBitmap(image)
        let expectedBitmap = MediaEditorBitmap(expected)
        let diff = comparePixels(actualBitmap, expectedBitmap, edgeMask: nil)
        self.measurements.append("\(name): \(image.width)x\(image.height) maxDelta \(diff.maxDelta)")
        if actualBitmap.bytes != expectedBitmap.bytes {
            self.fail("\(name): readback differs from CoreImage, maxDelta \(diff.maxDelta)")
        }
    }

    private func testReadbackMatchesCoreImage() {
        guard let device = MTLCreateSystemDefaultDevice(), let texture = loadTexture(image: MediaEditorExportFixtures.photo, device: device) else {
            self.fail("no Metal device or photo texture")
            return
        }
        self.checkReadback(device: device, texture: texture, mirror: false, name: "readback")
        self.checkReadback(device: device, texture: texture, mirror: true, name: "readback mirrored")
    }

    private func checkRatio(_ image: UIImage, expected: CGFloat, label: String) {
        guard let cgImage = image.cgImage else {
            self.fail("\(label): no CGImage")
            return
        }
        let ratio = CGFloat(cgImage.width) / CGFloat(cgImage.height)
        self.measurements.append("\(label): \(cgImage.width)x\(cgImage.height), ratio \(ratio), expected \(expected)")
        if abs(ratio - expected) / expected > 0.005 {
            self.fail("\(label): ratio \(ratio), expected \(expected) within 0.5%")
        }
    }

    private func testPanoramaPhotoComposes() {
        guard let panorama = UIImage(data: MediaEditorExportFixtures.data("photo-panorama.png")) else {
            self.fail("cannot load photo-panorama.png")
            return
        }
        let values = self.baseValues(width: 12000, height: 2000)
        guard let image = self.composeChat(values, input: .image(panorama), maxOutputSide: 2560.0, label: "panorama"), let cgImage = image.cgImage else {
            return
        }
        self.measurements.append("panorama: \(cgImage.width)x\(cgImage.height)")
        if abs(cgImage.width - 2560) > 1 || abs(cgImage.height - 427) > 1 {
            self.fail("panorama: \(cgImage.width)x\(cgImage.height), expected 2560x427 (±1)")
        }
        let cropped = values.withUpdatedCrop(rect: CGRect(x: 4500.0, y: 0.0, width: 3000.0, height: 2000.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        guard let croppedImage = self.composeChat(cropped, input: .image(panorama), maxOutputSide: 2560.0, label: "panorama 3:2 crop") else {
            return
        }
        self.checkRatio(croppedImage, expected: 1.5, label: "panorama 3:2 crop")
    }

    private func testOversizedPhotoIsDownscaledBeforeUpload() {
        let size = CGSize(width: 18000.0, height: 1500.0)
        let image = photoTestImage(size: size, opaque: true) { context in
            context.setFillColor(UIColor.red.cgColor)
            context.fill(CGRect(x: 0.0, y: 0.0, width: size.width / 2.0, height: size.height))
            context.setFillColor(UIColor.blue.cgColor)
            context.fill(CGRect(x: size.width / 2.0, y: 0.0, width: size.width / 2.0, height: size.height))
        }
        let values = self.baseValues(width: 18000, height: 1500)
        if let device = MTLCreateSystemDefaultDevice() {
            self.measurements.append("device texture side limit \(mediaEditorComposeMaxTextureSide(device: device))")
        }
        guard let result = self.composeChat(values, input: .image(image), maxOutputSide: 2560.0, label: "18000x1500") else {
            return
        }
        self.checkRatio(result, expected: 12.0, label: "18000x1500")
        let sampler = PhotoPixelSampler(result)
        self.assertColor(sampler, 0.25, 0.5, .red, "18000x1500")
        self.assertColor(sampler, 0.75, 0.5, .blue, "18000x1500")
    }

    private func testEditorResultMatchesImageInput() {
        guard let device = MTLCreateSystemDefaultDevice(), let texture = loadTexture(image: MediaEditorExportFixtures.photo, device: device) else {
            self.fail("no Metal device or photo texture")
            return
        }
        let values = self.baseValues(width: 3024, height: 4032).withUpdatedCrop(rect: CGRect(x: 301.0, y: 517.0, width: 2011.0, height: 1733.0), rotation: 0.0, orientation: .right, mirroring: true, perspective: .zero)
        guard let fromTexture = self.composeChat(values, input: .editorResult(texture), maxOutputSide: 1280.0, label: "editorResult")?.cgImage,
              let fromImage = self.composeChat(values, input: .image(MediaEditorExportFixtures.photo), maxOutputSide: 1280.0, label: "image")?.cgImage else {
            return
        }
        guard fromTexture.width == fromImage.width, fromTexture.height == fromImage.height else {
            self.fail("editorResult \(fromTexture.width)x\(fromTexture.height), image \(fromImage.width)x\(fromImage.height)")
            return
        }
        let diff = comparePixels(fromTexture, fromImage, edgeMask: nil)
        self.measurements.append("editorResult vs image: \(fromTexture.width)x\(fromTexture.height) maxDelta \(diff.maxDelta)")
        if diff.maxDelta != 0 {
            self.fail("editorResult and image inputs differ: maxDelta \(diff.maxDelta)")
        }
    }

    private func testIdentityUnchanged() {
        let values = self.baseValues()
        let canvas = mediaEditorNonStoryCanvasSize(originalDimensions: values.originalDimensions)
        guard let image = self.compose(values, label: "identity") else {
            return
        }
        let sampler = PhotoPixelSampler(image)
        if CGSize(width: sampler.width, height: sampler.height) != canvas {
            self.fail("identity: \(sampler.width)x\(sampler.height), expected \(canvas)")
        }
        self.assertColor(sampler, 0.25, 0.25, photoQuadrantTopLeft, "identity")
        self.assertColor(sampler, 0.75, 0.25, photoQuadrantTopRight, "identity")
        self.assertColor(sampler, 0.25, 0.75, photoQuadrantBottomLeft, "identity")
        self.assertColor(sampler, 0.75, 0.75, photoQuadrantBottomRight, "identity")
        self.assertColor(sampler, 0.5, 0.5, .white, "identity")

        guard let explicitImage = self.compose(values.withUpdatedCrop(rect: CGRect(x: 0.0, y: 0.0, width: 400.0, height: 300.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero), label: "explicit identity") else {
            return
        }
        let explicitSampler = PhotoPixelSampler(explicitImage)
        if explicitSampler.width != sampler.width || explicitSampler.height != sampler.height {
            self.fail("explicit identity: \(explicitSampler.width)x\(explicitSampler.height), expected \(sampler.width)x\(sampler.height)")
            return
        }
        for fy in stride(from: CGFloat(0.05), through: 0.95, by: 0.15) {
            for fx in stride(from: CGFloat(0.05), through: 0.95, by: 0.15) {
                if explicitSampler.color(fx: fx, fy: fy) != sampler.color(fx: fx, fy: fy) {
                    self.fail("explicit identity differs at (\(fx), \(fy))")
                }
            }
        }
    }

    private func testCropRectTopLeftQuadrant() {
        let values = self.baseValues().withUpdatedCrop(rect: CGRect(x: 0.0, y: 0.0, width: 200.0, height: 150.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        guard let image = self.compose(values, label: "top-left crop") else {
            return
        }
        let sampler = PhotoPixelSampler(image)
        if abs(Double(sampler.width) / Double(sampler.height) - 4.0 / 3.0) > 0.01 {
            self.fail("top-left crop: \(sampler.width)x\(sampler.height) is not 4:3")
        }
        for (fx, fy) in [(0.03, 0.03), (0.97, 0.03), (0.03, 0.9), (0.9, 0.9), (0.5, 0.5)] as [(CGFloat, CGFloat)] {
            self.assertColor(sampler, fx, fy, photoQuadrantTopLeft, "top-left crop")
        }
    }

    private func testOrientationLeft() {
        let values = self.baseValues().withUpdatedCrop(rect: nil, rotation: 0.0, orientation: .left, mirroring: false, perspective: .zero)
        guard let image = self.compose(values, label: "orientation left") else {
            return
        }
        let sampler = PhotoPixelSampler(image)
        if sampler.width >= sampler.height {
            self.fail("orientation left: \(sampler.width)x\(sampler.height) is not portrait")
        }
        self.assertColor(sampler, 0.25, 0.25, photoQuadrantTopRight, "orientation left")
        self.assertColor(sampler, 0.75, 0.25, photoQuadrantBottomRight, "orientation left")
        self.assertColor(sampler, 0.25, 0.75, photoQuadrantTopLeft, "orientation left")
        self.assertColor(sampler, 0.75, 0.75, photoQuadrantBottomLeft, "orientation left")
    }

    private func testMirrorFlipsMediaOnly() {
        let canvas = mediaEditorNonStoryCanvasSize(originalDimensions: PixelDimensions(width: 400, height: 300))
        let drawing = photoTestImage(size: canvas, opaque: false) { context in
            context.clear(CGRect(origin: .zero, size: canvas))
            context.setFillColor(UIColor.magenta.cgColor)
            context.fill(CGRect(x: canvas.width * 0.05, y: canvas.height * 0.2, width: canvas.width * 0.1, height: canvas.height * 0.1))
        }
        let values = self.baseValues()
            .withUpdatedDrawingAndEntities(drawing: drawing, entities: [])
            .withUpdatedCrop(rect: nil, rotation: 0.0, orientation: nil, mirroring: true, perspective: .zero)
        guard let image = self.compose(values, label: "mirror") else {
            return
        }
        let sampler = PhotoPixelSampler(image)
        self.assertColor(sampler, 0.1, 0.25, .magenta, "mirror")
        self.assertColor(sampler, 0.9, 0.25, photoQuadrantTopLeft, "mirror")
        self.assertColor(sampler, 0.3, 0.1, photoQuadrantTopRight, "mirror")
        self.assertColor(sampler, 0.25, 0.75, photoQuadrantBottomRight, "mirror")
        self.assertColor(sampler, 0.75, 0.75, photoQuadrantBottomLeft, "mirror")
    }

    private func testRotatedCropOrientedPixels() {
        let original = CGSize(width: 400.0, height: 300.0)
        let rotation: CGFloat = 12.0 * .pi / 180.0
        let rotated = photoRotatedSize(original, rotation: rotation)
        let cropSize = CGSize(width: 300.0, height: 225.0)
        let cropRect = CGRect(x: (rotated.width - cropSize.width) / 2.0, y: (rotated.height - cropSize.height) / 2.0, width: cropSize.width, height: cropSize.height)
        let values = self.baseValues().withUpdatedCrop(rect: cropRect, rotation: rotation, orientation: .left, mirroring: false, perspective: .zero)
        guard let image = self.compose(values, label: "rotated crop") else {
            return
        }
        let sampler = PhotoPixelSampler(image)
        if abs(Double(sampler.width) / Double(sampler.height) - 225.0 / 300.0) > 0.01 {
            self.fail("rotated crop: \(sampler.width)x\(sampler.height) is not 3:4")
        }
        self.assertColor(sampler, 0.5, 0.5, .white, "rotated crop")
        self.assertColor(sampler, 0.03, 0.03, photoQuadrantTopRight, "rotated crop")
        self.assertColor(sampler, 0.97, 0.03, photoQuadrantBottomRight, "rotated crop")
        self.assertColor(sampler, 0.97, 0.97, photoQuadrantBottomLeft, "rotated crop")
        self.assertColor(sampler, 0.03, 0.97, photoQuadrantTopLeft, "rotated crop")
        self.assertColor(sampler, (112.5 - 95.0) / 225.0, 0.5, photoQuadrantTopLeft, "rotated crop")
        self.assertColor(sampler, (112.5 - 95.0) / 225.0, 0.47, photoQuadrantTopLeft, "rotated crop")
    }

    private func testChatCompositionRendersTightCropFromSourcePixels() {
        let values = self.baseValues(width: 2016, height: 1512).withUpdatedCrop(rect: CGRect(x: 0.0, y: 0.0, width: 504.0, height: 378.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        guard let image = self.composeChat(values, input: .image(photoQuadrantImage(width: 2016.0, height: 1512.0)), maxOutputSide: 1280.0, label: "tight crop") else {
            return
        }
        let sampler = PhotoPixelSampler(image)
        if sampler.width != 504 || sampler.height != 378 {
            self.fail("tight crop: \(sampler.width)x\(sampler.height), expected 504x378")
        }
        self.assertColor(sampler, 0.5, 0.5, photoQuadrantTopLeft, "tight crop")
        self.assertColor(sampler, 0.99, 0.99, photoQuadrantTopLeft, "tight crop")
    }

    private func testOrientedOddCropEdgesAreOpaque() {
        let inputImage = photoTestImage(size: CGSize(width: 1920.0, height: 1440.0), opaque: true) { context in
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(x: 0.0, y: 0.0, width: 1920.0, height: 1440.0))
        }
        for orientation in [MediaCropOrientation.left, .right, .down] {
            let label = "odd crop \(orientation)"
            let values = self.baseValues(width: 1920, height: 1440).withUpdatedCrop(rect: CGRect(x: 101.0, y: 77.0, width: 715.0, height: 551.0), rotation: 0.0, orientation: orientation, mirroring: false, perspective: .zero)
            guard let image = self.composeChat(values, input: .image(inputImage), maxOutputSide: 1280.0, label: label) else {
                continue
            }
            let sampler = PhotoPixelSampler(image)
            let expectedSize = orientation.isSideward ? CGSize(width: 551.0, height: 715.0) : CGSize(width: 715.0, height: 551.0)
            if CGSize(width: sampler.width, height: sampler.height) != expectedSize {
                self.fail("\(label): \(sampler.width)x\(sampler.height), expected \(expectedSize)")
            }
            var worst = PhotoTestColor.white
            for x in 0 ..< sampler.width {
                for y in [0, sampler.height - 1] {
                    let color = sampler.color(x: CGFloat(x), y: CGFloat(y))
                    if color.r + color.a < worst.r + worst.a {
                        worst = color
                    }
                }
            }
            for y in 0 ..< sampler.height {
                for x in [0, sampler.width - 1] {
                    let color = sampler.color(x: CGFloat(x), y: CGFloat(y))
                    if color.r + color.a < worst.r + worst.a {
                        worst = color
                    }
                }
            }
            if !worst.isClose(to: .white, tolerance: 2) {
                self.fail("\(label): edge pixel \(worst)")
            }
        }
    }

    private func checkPerspectiveMarkers(orientation: MediaCropOrientation?, mirrored: Bool, label: String) {
        let original = CGSize(width: 400.0, height: 300.0)
        let rotation: CGFloat = 0.1
        let rotatedSize = photoRotatedSize(original, rotation: rotation)
        let cropRect = CGRect(origin: .zero, size: rotatedSize)
        let values = self.baseValues().withUpdatedCrop(rect: cropRect, rotation: rotation, orientation: orientation, mirroring: mirrored, perspective: MediaEditorCropPerspective(vertical: 0.4, horizontal: -0.3))
        guard let image = self.compose(values, inputImage: photoPerspectiveMarkerImage(), label: label) else {
            return
        }
        let sampler = PhotoPixelSampler(image)
        for marker in photoPerspectiveMarkers {
            let expected = photoPerspectiveExpectedPoint(CGPoint(x: marker.point.x * original.width, y: marker.point.y * original.height), original: original, values: values, cropRect: cropRect)
            self.assertColor(sampler, expected.x, expected.y, marker.color, "\(label) marker \(marker.point)")
        }
    }

    private func testPerspectiveMarkersLandWhereHomographySays() {
        self.checkPerspectiveMarkers(orientation: nil, mirrored: false, label: "perspective")
    }

    private func testPerspectiveWithOrientationAndMirror() {
        for orientation in [MediaCropOrientation.up, .left, .down, .right] {
            for mirrored in [false, true] {
                self.checkPerspectiveMarkers(orientation: orientation == .up ? nil : orientation, mirrored: mirrored, label: "perspective \(orientation) mirrored \(mirrored)")
            }
        }
    }
}
