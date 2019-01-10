import Foundation
import UIKit
import AsyncDisplayKit
import Accelerate


private func imageBuffer(from data: UnsafeMutableRawPointer!, width: vImagePixelCount, height: vImagePixelCount, rowBytes: Int) -> vImage_Buffer {
    return vImage_Buffer(data: data, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
}

private func blurredImage(image: CGImage, boxSize: UInt32, iterations: Int) -> CGImage? {
    guard let providerData = image.dataProvider?.data else {
        return nil
    }
    
    let bytes = image.bytesPerRow * image.height
    let inData = malloc(bytes)
    var inBuffer = imageBuffer(from: inData, width: vImagePixelCount(image.width), height: vImagePixelCount(image.height), rowBytes: image.bytesPerRow)
    
    let outData = malloc(bytes)
    var outBuffer = imageBuffer(from: outData, width: vImagePixelCount(image.width), height: vImagePixelCount(image.height), rowBytes: image.bytesPerRow)
    
    let tempSize = vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, nil, 0, 0, boxSize, boxSize, nil, vImage_Flags(kvImageEdgeExtend + kvImageGetTempBufferSize))
    let tempData = malloc(tempSize)
    
    defer {
        free(inData)
        free(outData)
        free(tempData)
    }
    
    let source = CFDataGetBytePtr(providerData)
    memcpy(inBuffer.data, source, bytes)
    
    for _ in 0..<iterations {
        vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, tempData, 0, 0, boxSize, boxSize, nil, vImage_Flags(kvImageEdgeExtend))
        
        let temp = inBuffer.data
        inBuffer.data = outBuffer.data
        outBuffer.data = temp
    }
    
    let context = image.colorSpace.flatMap {
        CGContext(data: inBuffer.data, width: image.width, height: image.height, bitsPerComponent: image.bitsPerComponent, bytesPerRow: image.bytesPerRow, space: $0, bitmapInfo: image.bitmapInfo.rawValue)
    }
    
    return context?.makeImage()
}

final class BlurredImageNode: ASDisplayNode {

}
