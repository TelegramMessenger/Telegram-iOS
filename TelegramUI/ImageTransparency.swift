import UIKit
import Accelerate

func imageHasTransparency(_ image: UIImage) -> Bool {
    guard let cgImage = image.cgImage, cgImage.bitsPerComponent == 8, cgImage.bitsPerPixel == 32 else {
        return false
    }
    let alphaInfo = cgImage.alphaInfo
    guard alphaInfo == .first || alphaInfo == .last || alphaInfo == .premultipliedFirst || alphaInfo == .premultipliedLast else {
        return false
    }
    
    var sourceBuffer = vImage_Buffer()
    defer {
        free(sourceBuffer.data)
    }
    
    var cgImageFormat = vImage_CGImageFormat(
        bitsPerComponent: UInt32(cgImage.bitsPerComponent),
        bitsPerPixel: UInt32(cgImage.bitsPerPixel),
        colorSpace: Unmanaged.passUnretained(cgImage.colorSpace!),
        bitmapInfo: cgImage.bitmapInfo,
        version: 0,
        decode: nil,
        renderingIntent: .defaultIntent
    )
    
    let noFlags = vImage_Flags(kvImageNoFlags)
    var error = vImageBuffer_InitWithCGImage(&sourceBuffer, &cgImageFormat, nil, cgImage, noFlags)
    assert(error == kvImageNoError)
    
    if alphaInfo == .premultipliedLast {
        error = vImageUnpremultiplyData_RGBA8888(&sourceBuffer, &sourceBuffer, noFlags)
    } else if alphaInfo == .premultipliedFirst {
        error = vImageUnpremultiplyData_ARGB8888(&sourceBuffer, &sourceBuffer, noFlags)
    }
    assert(error == kvImageNoError)
    
    let histogramBins = (0...3).map { _ in
        return [vImagePixelCount](repeating: 0, count: 256)
    }
    var mutableHistogram: [UnsafeMutablePointer<vImagePixelCount>?] = histogramBins.map {
        return UnsafeMutablePointer<vImagePixelCount>(mutating: $0)
    }
    error = vImageHistogramCalculation_ARGB8888(&sourceBuffer, &mutableHistogram, noFlags)
    assert(error == kvImageNoError)
    
    let alphaBinIndex = alphaInfo == .last || alphaInfo == .premultipliedLast ? 3 : 0
    for i in 0 ..< 255 {
        if histogramBins[alphaBinIndex][i] > 0 {
            return true
        }
    }
    return false
}
