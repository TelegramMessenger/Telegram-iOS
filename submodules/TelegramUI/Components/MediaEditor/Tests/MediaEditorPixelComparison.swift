import Foundation
import CoreGraphics
import CoreVideo
import ImageIO

struct PixelDiff {
    let maxDelta: Int
    let meanDelta: SIMD4<Double>
    let outOfToleranceShare: Double
    let maxNonEdgeDelta: Int
    let edgeShare: Double
}

let pixelDiffTolerance = 2
let edgeGradientThreshold = 24

struct MediaEditorBitmap {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(_ image: CGImage) {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)!
            context.setBlendMode(.copy)
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        self.width = width
        self.height = height
        self.bytes = bytes
    }
}

func edgeMask(for bitmap: MediaEditorBitmap) -> [Bool] {
    let width = bitmap.width
    let height = bitmap.height
    var mask = [Bool](repeating: false, count: width * height)
    bitmap.bytes.withUnsafeBufferPointer { bytes in
        mask.withUnsafeMutableBufferPointer { mask in
            for y in 0 ..< height {
                for x in 0 ..< width {
                    let center = (y * width + x) * 4
                    var isEdge = false
                    for dy in -1 ... 1 where !isEdge {
                        let ny = y + dy
                        if ny < 0 || ny >= height {
                            continue
                        }
                        for dx in -1 ... 1 where !isEdge {
                            let nx = x + dx
                            if nx < 0 || nx >= width || (dx == 0 && dy == 0) {
                                continue
                            }
                            let neighbour = (ny * width + nx) * 4
                            for channel in 0 ..< 4 {
                                if abs(Int(bytes[center + channel]) - Int(bytes[neighbour + channel])) > edgeGradientThreshold {
                                    isEdge = true
                                    break
                                }
                            }
                        }
                    }
                    mask[y * width + x] = isEdge
                }
            }
        }
    }
    return mask
}

func comparePixels(_ a: CGImage, _ b: CGImage, edgeMask: [Bool]?) -> PixelDiff {
    return comparePixels(MediaEditorBitmap(a), MediaEditorBitmap(b), edgeMask: edgeMask)
}

func comparePixels(_ a: MediaEditorBitmap, _ b: MediaEditorBitmap, edgeMask: [Bool]?) -> PixelDiff {
    precondition(a.width == b.width && a.height == b.height)
    let pixelCount = a.width * a.height
    var maxDelta = 0
    var maxNonEdgeDelta = 0
    var sums = SIMD4<Double>(repeating: 0.0)
    var outOfTolerance = 0
    var edgeCount = 0
    a.bytes.withUnsafeBufferPointer { aBytes in
        b.bytes.withUnsafeBufferPointer { bBytes in
            var channelSums: (Int, Int, Int, Int) = (0, 0, 0, 0)
            for pixel in 0 ..< pixelCount {
                let offset = pixel * 4
                let d0 = abs(Int(aBytes[offset]) - Int(bBytes[offset]))
                let d1 = abs(Int(aBytes[offset + 1]) - Int(bBytes[offset + 1]))
                let d2 = abs(Int(aBytes[offset + 2]) - Int(bBytes[offset + 2]))
                let d3 = abs(Int(aBytes[offset + 3]) - Int(bBytes[offset + 3]))
                channelSums.0 += d2
                channelSums.1 += d1
                channelSums.2 += d0
                channelSums.3 += d3
                let delta = max(max(d0, d1), max(d2, d3))
                if delta > maxDelta {
                    maxDelta = delta
                }
                if delta > pixelDiffTolerance {
                    outOfTolerance += 1
                }
                let isEdge = edgeMask?[pixel] ?? false
                if isEdge {
                    edgeCount += 1
                } else if delta > maxNonEdgeDelta {
                    maxNonEdgeDelta = delta
                }
            }
            sums = SIMD4<Double>(Double(channelSums.0), Double(channelSums.1), Double(channelSums.2), Double(channelSums.3))
        }
    }
    let count = Double(max(1, pixelCount))
    return PixelDiff(
        maxDelta: maxDelta,
        meanDelta: sums / count,
        outOfToleranceShare: Double(outOfTolerance) / count,
        maxNonEdgeDelta: maxNonEdgeDelta,
        edgeShare: Double(edgeCount) / count
    )
}

func cgImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
    guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else {
        return nil
    }
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        return nil
    }
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let bytesPerRow = width * 4
    var data = Data(count: bytesPerRow * height)
    data.withUnsafeMutableBytes { buffer in
        for row in 0 ..< height {
            memcpy(buffer.baseAddress! + row * bytesPerRow, baseAddress + row * sourceBytesPerRow, bytesPerRow)
        }
    }
    guard let provider = CGDataProvider(data: data as CFData) else {
        return nil
    }
    return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
}

func writePNG(_ image: CGImage, to url: URL) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        return false
    }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}
