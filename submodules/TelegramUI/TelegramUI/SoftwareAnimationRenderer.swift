import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramUIPrivateModule

final class SoftwareAnimationRenderer: ASDisplayNode, AnimationRenderer {
    func render(width: Int, height: Int, bytes: UnsafeRawPointer, length: Int) {
        let image = generateImagePixel(CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, pixelGenerator: { _, pixelData in
            decodeYUVAToRGBA(bytes.assumingMemoryBound(to: UInt8.self), pixelData, Int32(width), Int32(height))
        })
        
        self.contents = image?.cgImage
    }
}
