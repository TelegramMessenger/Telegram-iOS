import Foundation
import UIKit
import AnimationCache
import Display
import RLottieBinding
import GZip

public func cacheLottieAnimation(data: Data, width: Int, height: Int, writer: AnimationCacheItemWriter) {
    writer.queue.async {
        let decompressedData = TGGUnzipData(data, 1 * 1024 * 1024) ?? data
        guard let animation = LottieInstance(data: decompressedData, fitzModifier: .none, colorReplacements: nil, cacheKey: "") else {
            writer.finish()
            return
        }
        
        let frameDuration = 1.0 / Double(animation.frameRate)
        for i in 0 ..< animation.frameCount {
            if writer.isCancelled {
                break
            }
            writer.add(with: { surface in
                animation.renderFrame(with: i, into: surface.argb, width: Int32(surface.width), height: Int32(surface.height), bytesPerRow: Int32(surface.bytesPerRow))
            }, proposedWidth: width, proposedHeight: height, duration: frameDuration)
        }
        
        writer.finish()
    }
}

public func cacheStillSticker(path: String, width: Int, height: Int, writer: AnimationCacheItemWriter) {
    writer.queue.async {
        writer.finish()
    }
}
