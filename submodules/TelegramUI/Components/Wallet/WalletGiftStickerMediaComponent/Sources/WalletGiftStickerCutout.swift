import Foundation
import Accelerate

/// Replaces premultiplied BGRA pixels with a white die-cut mask. All expensive
/// image operations run in vImage, including on unoptimized simulator builds.
func walletGiftStickerCutout(bytes: UnsafeMutablePointer<UInt8>, side: Int) -> Bool {
    let count = side * side
    let alpha = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
    let grown = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
    defer { alpha.deallocate(); grown.deallocate() }
    var source = vImage_Buffer(data: bytes, height: vImagePixelCount(side), width: vImagePixelCount(side), rowBytes: side * 4)
    var a = vImage_Buffer(data: alpha, height: vImagePixelCount(side), width: vImagePixelCount(side), rowBytes: side)
    var b = vImage_Buffer(data: grown, height: vImagePixelCount(side), width: vImagePixelCount(side), rowBytes: side)
    let flags = vImage_Flags(kvImageEdgeExtend)
    guard vImageExtractChannel_ARGB8888(&source, &a, 3, 0) == kvImageNoError else { return false }
    let solid = (0 ... 255).map { UInt8($0 >= 128 ? 255 : 0) }
    guard solid.withUnsafeBufferPointer({ vImageTableLookUp_Planar8(&a, &b, $0.baseAddress!, 0) }) == kvImageNoError,
          vImageCopyBuffer(&b, &a, 1, 0) == kvImageNoError else { return false }
    // Reference v14: Gaussian sigma 5.35 / 384 of the canvas, followed by
    // alpha * 10 - 150. A separable integer kernel keeps this in Accelerate.
    let sigma = Double(side) * 5.35 / 384
    let extent = Int(ceil(sigma * 3))
    let values = (-extent ... extent).map { exp(-Double($0 * $0) / (2 * sigma * sigma)) }
    let sum = values.reduce(0, +)
    var kernel = values.map { Int16(($0 / sum * 16384).rounded()) }
    kernel[extent] += Int16(16384 - kernel.reduce(0) { $0 + Int($1) })
    let blurred = kernel.withUnsafeBufferPointer { k -> Bool in
        vImageConvolve_Planar8(&a, &b, nil, 0, 0, k.baseAddress!, 1, UInt32(kernel.count), 16384, 0, flags) == kvImageNoError
            && vImageConvolve_Planar8(&b, &a, nil, 0, 0, k.baseAddress!, UInt32(kernel.count), 1, 16384, 0, flags) == kvImageNoError
    }
    guard blurred else { return false }
    let ramp = (0 ... 255).map { UInt8(max(0, min(255, $0 * 10 - 150))) }
    guard ramp.withUnsafeBufferPointer({ vImageTableLookUp_Planar8(&a, &b, $0.baseAddress!, 0) }) == kvImageNoError else { return false }
    let threshold = (0 ... 255).map { UInt8($0 >= 128 ? 255 : 0) }
    guard threshold.withUnsafeBufferPointer({ vImageTableLookUp_Planar8(&b, &a, $0.baseAddress!, 0) }) == kvImageNoError else { return false }
    if #available(iOS 16.0, macOS 13.0, *) {
        // The art has 3.5% padding, larger than the cutout margin, so all
        // exterior pixels are connected to this transparent corner.
        guard vImageFloodFill_Planar8(&a, nil, 0, 0, 1, 4, 0) == kvImageNoError else { return false }
    } else {
        // iOS 15 compatibility: mark each exterior pixel once.
        var stack = [0]
        alpha[0] = 1
        while let i = stack.popLast() {
            func visit(_ next: Int) {
                if alpha[next] == 0 { alpha[next] = 1; stack.append(next) }
            }
            if i % side > 0 { visit(i - 1) }
            if i % side + 1 < side { visit(i + 1) }
            if i >= side { visit(i - side) }
            if i + side < count { visit(i + side) }
        }
    }
    let pixels = UnsafeMutableRawPointer(bytes).assumingMemoryBound(to: UInt32.self)
    var hasPixels = false
    for i in 0 ..< count {
        let value: UInt8 = alpha[i] == 0 ? 255 : grown[i]
        pixels[i] = UInt32(value) * 0x01010101
        if value > 0 { hasPixels = true }
    }
    return hasPixels
}
