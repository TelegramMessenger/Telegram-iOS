import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramUIPrivateModule

final class SoftwareAnimationRenderer: ASDisplayNode, AnimationRenderer {
    func render(queue: Queue, width: Int, height: Int, data: Data, type: AnimationRendererFrameType, completion: @escaping () -> Void) {
        queue.async { [weak self] in
            let image = generateImagePixel(CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, pixelGenerator: { _, pixelData in
                switch type {
                case .yuva:
                    data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                        decodeYUVAToRGBA(bytes, pixelData, Int32(width), Int32(height))
                    }
                case .argb:
                    data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                        memcpy(pixelData, bytes, data.count)
                    }
                }
            })
            
            Queue.mainQueue().async {
                self?.contents = image?.cgImage
                completion()
            }
        }
    }
}
