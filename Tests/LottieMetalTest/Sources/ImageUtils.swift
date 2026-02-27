import Foundation
import UIKit

private func alignUp(size: Int, align: Int) -> Int {
    precondition(((align - 1) & align) == 0, "Align must be a power of two")

    let alignmentMask = align - 1
    return (size + alignmentMask) & ~alignmentMask
}

final class ImageContext {
    let context: CGContext
    
    init(width: Int, height: Int, isMask: Bool = false) {
        let bytesPerRow: Int
        let colorSpace: CGColorSpace
        let bitmapInfo: CGBitmapInfo
        
        if isMask {
            bytesPerRow = alignUp(size: width, align: 16)
            colorSpace = CGColorSpaceCreateDeviceGray()
            bitmapInfo = CGBitmapInfo(rawValue: 0)
        } else {
            bytesPerRow = alignUp(size: width * 4, align: 16)
            colorSpace = CGColorSpaceCreateDeviceRGB()
            bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        }
        
        self.context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)!
        
        self.context.clear(CGRect(origin: CGPoint(), size: CGSize(width: width, height: height)))
        
        //context.interpolationQuality = .none
        //context.setShouldAntialias(false)
        //context.setAllowsAntialiasing(false)
    }
    
    func makeImage() -> UIImage {
        return UIImage(cgImage: context.makeImage()!)
    }
}
