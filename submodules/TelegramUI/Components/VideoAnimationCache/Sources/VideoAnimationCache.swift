import Foundation
import UIKit
import AnimationCache
import Display
import AnimatedStickerNode
import SwiftSignalKit

public func cacheVideoAnimation(path: String, width: Int, height: Int, writer: AnimationCacheItemWriter) {
    let queue = Queue()
    queue.async {
        guard let frameSource = makeVideoStickerDirectFrameSource(queue: queue, path: path, width: width, height: height, cachePathPrefix: nil) else {
            return
        }
        let frameDuration = 1.0 / Double(frameSource.frameRate)
        while true {
            if let frame = frameSource.takeFrame(draw: true) {
                //AnimatedStickerFrame(data: frameData, type: .argb, width: self.width, height: self.height, bytesPerRow: self.bytesPerRow, index: frameIndex, isLastFrame: frameIndex == self.frameCount - 1, totalFrames: self.frameCount, multiplyAlpha: true)
                if case .argb = frame.type {
                    let frameWidth = frame.width
                    let frameHeight = frame.height
                    let bytesPerRow = frame.bytesPerRow
                    frame.data.withUnsafeBytes { bytes -> Void in
                        writer.add(bytes: bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), length: bytes.count, width: Int(frameWidth), height: Int(frameHeight), bytesPerRow: Int(bytesPerRow), duration: frameDuration)
                    }
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        writer.finish()
    }
}
