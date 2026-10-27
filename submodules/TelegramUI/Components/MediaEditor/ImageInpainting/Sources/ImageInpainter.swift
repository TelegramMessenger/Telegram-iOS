import Foundation
import CoreGraphics
import CoreML
import Vision
import Accelerate
import SwiftSignalKit

public struct ImageInpaintingPatch {
    public let image: CGImage
    public let rect: CGRect
}

@available(iOS 17.0, *)
public final class ImageInpainter {
    public private(set) static var shared: ImageInpainter?

    public static func loadShared() -> Signal<ImageInpainter?, NoError> {
        if let shared = self.shared {
            return .single(shared)
        }
        return Signal<ImageInpainter?, NoError> { subscriber in
            imageInpaintingQueue.async {
                subscriber.putNext(try? ImageInpainter(modelPath: imageInpaintingModelPath()))
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
        |> deliverOnMainQueue
        |> map { inpainter -> ImageInpainter? in
            if let shared = self.shared {
                return shared
            }
            self.shared = inpainter
            return inpainter
        }
    }

    static func resetShared() {
        self.shared = nil
    }
    
    private static let resolution = 512

    private let model: MLModel
    private let imageInput: MLMultiArray
    private let maskInput: MLMultiArray

    private init(modelPath: String) throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        self.model = try MLModel(contentsOf: URL(fileURLWithPath: modelPath), configuration: configuration)
        let side = NSNumber(value: ImageInpainter.resolution)
        self.imageInput = try MLMultiArray(shape: [1, 3, side, side], dataType: .float32)
        self.maskInput = try MLMultiArray(shape: [1, 1, side, side], dataType: .float32)
    }

    public func inpaint(image: CGImage, strokeMask: CGImage) -> Signal<ImageInpaintingPatch?, NoError> {
        return Signal { subscriber in
            imageInpaintingQueue.async {
                subscriber.putNext(self.process(image: image, strokeMask: strokeMask))
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }

    private func process(image: CGImage, strokeMask: CGImage) -> ImageInpaintingPatch? {
        let width = image.width
        let height = image.height
        guard var hole = renderAlpha(strokeMask, width: width, height: height) else {
            return nil
        }
        guard let strokeBox = boundingBox(of: hole, width: width, height: height) else {
            return nil
        }

        addMatchingObjects(to: &hole, image: image, width: width, height: height, strokeBox: strokeBox)

        guard let holeBox = boundingBox(of: hole, width: width, height: height) else {
            return nil
        }
        let longSide = max(width, height)
        let dilationRadius = max(2, Int(Double(longSide) * 0.006))
        let dilatedBox = holeBox.insetBy(dx: -dilationRadius, dy: -dilationRadius).clamped(width: width, height: height)
        let crop = cropRect(around: dilatedBox, width: width, height: height)

        var cropHole = extract(hole, width: width, rect: crop)
        cropHole = dilate(cropHole, width: crop.width, height: crop.height, radius: dilationRadius)

        guard let cropImage = image.cropping(to: CGRect(x: crop.x, y: crop.y, width: crop.width, height: crop.height)) else {
            return nil
        }
        let side = ImageInpainter.resolution
        guard let modelPixels = renderRGBA(cropImage, width: side, height: side) else {
            return nil
        }
        let modelHole = resizeNearest(cropHole, width: crop.width, height: crop.height, toWidth: side, toHeight: side)
        guard let filledPixels = self.predict(pixels: modelPixels, hole: modelHole) else {
            return nil
        }
        guard let filledImage = makeImage(rgba: filledPixels, width: side, height: side), let fill = renderRGBA(filledImage, width: crop.width, height: crop.height) else {
            return nil
        }

        let feather = max(1, Int(Double(max(crop.width, crop.height)) * 0.004))
        let weights = boxBlur(dilate(cropHole, width: crop.width, height: crop.height, radius: feather), width: crop.width, height: crop.height, radius: feather)

        var patch = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        for i in 0 ..< crop.width * crop.height {
            let weight = Int(max(weights[i], cropHole[i]))
            if weight == 0 {
                continue
            }
            patch[i * 4] = UInt8((Int(fill[i * 4]) * weight + 127) / 255)
            patch[i * 4 + 1] = UInt8((Int(fill[i * 4 + 1]) * weight + 127) / 255)
            patch[i * 4 + 2] = UInt8((Int(fill[i * 4 + 2]) * weight + 127) / 255)
            patch[i * 4 + 3] = UInt8(weight)
        }
        guard let patchImage = makeImage(rgba: patch, width: crop.width, height: crop.height) else {
            return nil
        }
        return ImageInpaintingPatch(image: patchImage, rect: CGRect(x: crop.x, y: crop.y, width: crop.width, height: crop.height))
    }

    private func predict(pixels: [UInt8], hole: [UInt8]) -> [UInt8]? {
        let side = ImageInpainter.resolution
        let plane = side * side
        let imagePointer = self.imageInput.dataPointer.assumingMemoryBound(to: Float32.self)
        let maskPointer = self.maskInput.dataPointer.assumingMemoryBound(to: Float32.self)
        for i in 0 ..< plane {
            imagePointer[i] = Float32(pixels[i * 4])
            imagePointer[plane + i] = Float32(pixels[i * 4 + 1])
            imagePointer[2 * plane + i] = Float32(pixels[i * 4 + 2])
            maskPointer[i] = hole[i] > 127 ? 0.0 : 1.0
        }
        guard let input = try? MLDictionaryFeatureProvider(dictionary: ["image": self.imageInput, "mask": self.maskInput]), let output = try? self.model.prediction(from: input), let result = output.featureValue(for: "result")?.multiArrayValue else {
            return nil
        }
        var values = [Float32](repeating: 0.0, count: 3 * plane)
        switch result.dataType {
        case .float16:
            let pointer = result.dataPointer.assumingMemoryBound(to: Float16.self)
            for i in 0 ..< 3 * plane {
                values[i] = Float32(pointer[i])
            }
        default:
            let pointer = result.dataPointer.assumingMemoryBound(to: Float32.self)
            for i in 0 ..< 3 * plane {
                values[i] = pointer[i]
            }
        }
        var out = [UInt8](repeating: 255, count: plane * 4)
        for i in 0 ..< plane {
            out[i * 4] = UInt8(max(0.0, min(255.0, values[i].rounded())))
            out[i * 4 + 1] = UInt8(max(0.0, min(255.0, values[plane + i].rounded())))
            out[i * 4 + 2] = UInt8(max(0.0, min(255.0, values[2 * plane + i].rounded())))
        }
        return out
    }

    private func addMatchingObjects(to hole: inout [UInt8], image: CGImage, width: Int, height: Int, strokeBox: PixelRect) {
        let margin = max(strokeBox.width, strokeBox.height)
        let analysisRect = strokeBox.insetBy(dx: -margin, dy: -margin).clamped(width: width, height: height)
        guard let analysisImage = image.cropping(to: CGRect(x: analysisRect.x, y: analysisRect.y, width: analysisRect.width, height: analysisRect.height)) else {
            return
        }
        let handler = VNImageRequestHandler(cgImage: analysisImage, options: [:])
        let foregroundRequest = VNGenerateForegroundInstanceMaskRequest()
        let personRequest = VNGeneratePersonInstanceMaskRequest()
        guard (try? handler.perform([foregroundRequest, personRequest])) != nil else {
            return
        }
        let observations = (foregroundRequest.results ?? []) + (personRequest.results ?? [])
        let stroke = hole
        for observation in observations {
            let selected = matchingInstances(in: observation, stroke: stroke, width: width, analysisRect: analysisRect)
            guard !selected.isEmpty, let mask = try? observation.generateScaledMaskForImage(forInstances: selected, from: handler) else {
                continue
            }
            CVPixelBufferLockBaseAddress(mask, .readOnly)
            let maskWidth = CVPixelBufferGetWidth(mask)
            let maskHeight = CVPixelBufferGetHeight(mask)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
            if let base = CVPixelBufferGetBaseAddress(mask), maskWidth == analysisRect.width, maskHeight == analysisRect.height {
                for y in 0 ..< maskHeight {
                    let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float32.self)
                    let holeRow = (analysisRect.y + y) * width + analysisRect.x
                    for x in 0 ..< maskWidth where row[x] > 0.5 {
                        hole[holeRow + x] = 255
                    }
                }
            }
            CVPixelBufferUnlockBaseAddress(mask, .readOnly)
        }
    }

    private func matchingInstances(in observation: VNInstanceMaskObservation, stroke: [UInt8], width: Int, analysisRect: PixelRect) -> IndexSet {
        let labels = observation.instanceMask
        CVPixelBufferLockBaseAddress(labels, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(labels, .readOnly)
        }
        guard let base = CVPixelBufferGetBaseAddress(labels) else {
            return IndexSet()
        }
        let labelWidth = CVPixelBufferGetWidth(labels)
        let labelHeight = CVPixelBufferGetHeight(labels)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(labels)
        var areas = [Int](repeating: 0, count: 256)
        var overlaps = [Int](repeating: 0, count: 256)
        var strokeArea = 0
        for y in 0 ..< labelHeight {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            let holeY = analysisRect.y + min(analysisRect.height - 1, y * analysisRect.height / labelHeight)
            for x in 0 ..< labelWidth {
                let holeX = analysisRect.x + min(analysisRect.width - 1, x * analysisRect.width / labelWidth)
                let inStroke = stroke[holeY * width + holeX] > 127
                let label = Int(row[x])
                if inStroke {
                    strokeArea += 1
                }
                if label != 0 {
                    areas[label] += 1
                    if inStroke {
                        overlaps[label] += 1
                    }
                }
            }
        }
        var selected = IndexSet()
        guard strokeArea > 0 else {
            return selected
        }
        for label in observation.allInstances where label < 256 && areas[label] > 0 {
            let coveredFraction = Double(overlaps[label]) / Double(areas[label])
            let relativeSize = Double(areas[label]) / Double(strokeArea)
            if coveredFraction >= 0.2 && relativeSize <= 3.0 {
                selected.insert(label)
            }
        }
        return selected
    }
}

struct PixelRect {
    var x: Int
    var y: Int
    var width: Int
    var height: Int

    func insetBy(dx: Int, dy: Int) -> PixelRect {
        return PixelRect(x: self.x + dx, y: self.y + dy, width: self.width - dx * 2, height: self.height - dy * 2)
    }

    func clamped(width: Int, height: Int) -> PixelRect {
        let minX = max(0, self.x)
        let minY = max(0, self.y)
        let maxX = min(width, self.x + self.width)
        let maxY = min(height, self.y + self.height)
        return PixelRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
    }
}

private func cropRect(around box: PixelRect, width: Int, height: Int) -> PixelRect {
    let side = max(Int(Double(max(box.width, box.height)) * 2.0), 512)
    let cropWidth = min(side, width)
    let cropHeight = min(side, height)
    let x = min(max(0, box.x + box.width / 2 - cropWidth / 2), width - cropWidth)
    let y = min(max(0, box.y + box.height / 2 - cropHeight / 2), height - cropHeight)
    return PixelRect(x: x, y: y, width: cropWidth, height: cropHeight)
}

private func boundingBox(of mask: [UInt8], width: Int, height: Int) -> PixelRect? {
    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1
    for y in 0 ..< height {
        let row = y * width
        for x in 0 ..< width where mask[row + x] > 127 {
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }
    }
    guard maxX >= 0 else {
        return nil
    }
    return PixelRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

private func extract(_ mask: [UInt8], width: Int, rect: PixelRect) -> [UInt8] {
    var out = [UInt8](repeating: 0, count: rect.width * rect.height)
    for y in 0 ..< rect.height {
        let source = (rect.y + y) * width + rect.x
        out.replaceSubrange(y * rect.width ..< (y + 1) * rect.width, with: mask[source ..< source + rect.width])
    }
    return out
}

private func resizeNearest(_ mask: [UInt8], width: Int, height: Int, toWidth: Int, toHeight: Int) -> [UInt8] {
    var out = [UInt8](repeating: 0, count: toWidth * toHeight)
    for y in 0 ..< toHeight {
        let sourceRow = min(height - 1, y * height / toHeight) * width
        for x in 0 ..< toWidth {
            out[y * toWidth + x] = mask[sourceRow + min(width - 1, x * width / toWidth)]
        }
    }
    return out
}

private func dilate(_ mask: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
    guard radius > 0 else {
        return mask
    }
    var source = mask
    var destination = [UInt8](repeating: 0, count: mask.count)
    let kernel = vImagePixelCount(radius * 2 + 1)
    source.withUnsafeMutableBytes { sourceBytes in
        destination.withUnsafeMutableBytes { destinationBytes in
            var sourceBuffer = vImage_Buffer(data: sourceBytes.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
            var destinationBuffer = vImage_Buffer(data: destinationBytes.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
            vImageMax_Planar8(&sourceBuffer, &destinationBuffer, nil, 0, 0, kernel, kernel, vImage_Flags(kvImageNoFlags))
        }
    }
    return destination
}

private func boxBlur(_ mask: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
    guard radius > 0 else {
        return mask
    }
    var source = mask
    var destination = [UInt8](repeating: 0, count: mask.count)
    let kernel = UInt32(radius * 2 + 1)
    source.withUnsafeMutableBytes { sourceBytes in
        destination.withUnsafeMutableBytes { destinationBytes in
            var sourceBuffer = vImage_Buffer(data: sourceBytes.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
            var destinationBuffer = vImage_Buffer(data: destinationBytes.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
            vImageBoxConvolve_Planar8(&sourceBuffer, &destinationBuffer, nil, 0, 0, kernel, kernel, 0, vImage_Flags(kvImageEdgeExtend))
        }
    }
    return destination
}

private func renderAlpha(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
    var out = [UInt8](repeating: 0, count: width * height)
    let success = out.withUnsafeMutableBytes { bytes -> Bool in
        guard let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else {
            return false
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    return success ? out : nil
}

private func renderRGBA(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
    var out = [UInt8](repeating: 0, count: width * height * 4)
    let success = out.withUnsafeMutableBytes { bytes -> Bool in
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB), let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return false
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    return success ? out : nil
}

private func makeImage(rgba: [UInt8], width: Int, height: Int) -> CGImage? {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB), let provider = CGDataProvider(data: Data(rgba) as CFData) else {
        return nil
    }
    return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
}
