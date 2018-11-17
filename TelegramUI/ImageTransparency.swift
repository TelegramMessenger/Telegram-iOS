import UIKit
import Accelerate

private func generateHistogram(cgImage: CGImage) -> ([[vImagePixelCount]], Int)? {
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
    
    if cgImage.alphaInfo == .premultipliedLast {
        error = vImageUnpremultiplyData_RGBA8888(&sourceBuffer, &sourceBuffer, noFlags)
    } else if cgImage.alphaInfo == .premultipliedFirst {
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
    
    let alphaBinIndex = [.last, .premultipliedLast].contains(cgImage.alphaInfo) ? 3 : 0
    return (histogramBins, alphaBinIndex)
}

func imageHasTransparency(_ cgImage: CGImage) -> Bool {
    guard cgImage.bitsPerComponent == 8, cgImage.bitsPerPixel == 32 else {
        return false
    }
    guard [.first, .last, .premultipliedFirst, .premultipliedLast].contains(cgImage.alphaInfo) else {
        return false
    }
    if let (histogramBins, alphaBinIndex) = generateHistogram(cgImage: cgImage) {
        for i in 0 ..< 255 {
            if histogramBins[alphaBinIndex][i] > 0 {
                return true
            }
        }
    }
    return false
}

func imageIsMonochrome(_ cgImage: CGImage) -> Bool {
    guard cgImage.bitsPerComponent == 8, cgImage.bitsPerPixel == 32 else {
        return false
    }
    if let (histogramBins, alphaBinIndex) = generateHistogram(cgImage: cgImage) {
        
    }
    
//    SSE, bias = 0, [0,0,0]
//    if adjust_color_bias:
//    bias = ImageStat.Stat(thumb).mean[:3]
//    bias = [b - sum(bias)/3 for b in bias ]
//    for pixel in thumb.getdata():
//    mu = sum(pixel)/3
//    SSE += sum((pixel[i] - mu - bias[i])*(pixel[i] - mu - bias[i]) for i in [0,1,2])
    
    
    return false
}
