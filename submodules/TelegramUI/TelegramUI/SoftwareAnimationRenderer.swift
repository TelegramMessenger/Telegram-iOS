import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramUIPrivateModule

final class SoftwareAnimationRenderer: ASDisplayNode, AnimationRenderer {
    func render(width: Int, height: Int, bytes: UnsafeRawPointer, length: Int) {
        let image = generateImagePixel(CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, pixelGenerator: { _, pixelData in
            if true {
                memcpy(pixelData, bytes, length)
            } else {
                encodeBRGR422AToRGBA(bytes.assumingMemoryBound(to: UInt8.self), bytes.assumingMemoryBound(to: UInt8.self).advanced(by: width * 2 * height), pixelData, Int32(width), Int32(height))
            }
        })
        
        self.contents = image?.cgImage
    }
}
