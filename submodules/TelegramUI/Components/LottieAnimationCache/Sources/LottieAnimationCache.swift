import Foundation
import UIKit
import AnimationCache
import Display
import RLottieBinding
import GZip

public func cacheLottieAnimation(data: Data, width: Int, height: Int, writer: AnimationCacheItemWriter) {
    let decompressedData = TGGUnzipData(data, 512 * 1024) ?? data
    guard let animation = LottieInstance(data: decompressedData, fitzModifier: .none, colorReplacements: nil, cacheKey: "") else {
        writer.finish()
        return
    }
    let size = CGSize(width: width, height: height)
    let context = DrawingContext(size: size, scale: 1.0, opaque: false, clear: true)
    let frameDuration = 1.0 / Double(animation.frameRate)
    for i in 0 ..< animation.frameCount {
        animation.renderFrame(with: i, into: context.bytes.assumingMemoryBound(to: UInt8.self), width: Int32(context.scaledSize.width), height: Int32(context.scaledSize.height), bytesPerRow: Int32(context.bytesPerRow))
        writer.add(bytes: context.bytes, length: context.length, width: Int(context.scaledSize.width), height: Int(context.scaledSize.height), bytesPerRow: Int(context.bytesPerRow), duration: frameDuration)
    }
    
    writer.finish()
}
