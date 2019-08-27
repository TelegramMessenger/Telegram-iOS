import UIKit
import Accelerate

private func imageBuffer(from data: UnsafeMutableRawPointer!, width: vImagePixelCount, height: vImagePixelCount, rowBytes: Int) -> vImage_Buffer {
    return vImage_Buffer(data: data, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
}

public func blurredImage(_ image: UIImage, radius: CGFloat, iterations: Int = 3) -> UIImage? {
    guard let cgImage = image.cgImage, let providerData = cgImage.dataProvider?.data else {
        return nil
    }
    
    if image.size.width <= 0.0 || image.size.height <= 0 || radius <= 0 {
        return image
    }
    
    var boxSize = UInt32(radius)
    if boxSize % 2 == 0 {
        boxSize += 1
    }
    
    let bytes = cgImage.bytesPerRow * cgImage.height
    let inData = malloc(bytes)
    var inBuffer = imageBuffer(from: inData, width: vImagePixelCount(cgImage.width), height: vImagePixelCount(cgImage.height), rowBytes: cgImage.bytesPerRow)
    
    let outData = malloc(bytes)
    var outBuffer = imageBuffer(from: outData, width: vImagePixelCount(cgImage.width), height: vImagePixelCount(cgImage.height), rowBytes: cgImage.bytesPerRow)
    
    let tempSize = vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, nil, 0, 0, boxSize, boxSize, nil, vImage_Flags(kvImageEdgeExtend + kvImageGetTempBufferSize))
    let tempData = malloc(tempSize)
    
    defer {
        free(inData)
        free(outData)
        free(tempData)
    }
    
    
    let source = CFDataGetBytePtr(providerData)
    memcpy(inBuffer.data, source, bytes)
    
    for _ in 0 ..< iterations {
        vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, tempData, 0, 0, boxSize, boxSize, nil, vImage_Flags(kvImageEdgeExtend))
        
        let temp = inBuffer.data
        inBuffer.data = outBuffer.data
        outBuffer.data = temp
    }
    
    let context = cgImage.colorSpace.flatMap {
        CGContext(data: inBuffer.data, width: cgImage.width, height: cgImage.height, bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: cgImage.bytesPerRow, space: $0, bitmapInfo: cgImage.bitmapInfo.rawValue)
    }
    
    let blurredCGImage = context?.makeImage()
    if let blurredCGImage = blurredCGImage {
        return UIImage(cgImage: blurredCGImage, scale: image.scale, orientation: image.imageOrientation)
    } else {
        return nil
    }
}
