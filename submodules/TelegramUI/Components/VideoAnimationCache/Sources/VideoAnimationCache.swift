import Foundation
import UIKit
import AnimationCache
import Display
import AnimatedStickerNode
import SwiftSignalKit

private func roundUp(_ numToRound: Int, multiple: Int) -> Int {
    if multiple == 0 {
        return numToRound
    }
    
    let remainder = numToRound % multiple
    if remainder == 0 {
        return numToRound;
    }
    
    return numToRound + multiple - remainder
}

public func cacheVideoAnimation(path: String, width: Int, height: Int, writer: AnimationCacheItemWriter, firstFrameOnly: Bool) {
    let work: () -> Void = {
        guard let frameSource = makeVideoStickerDirectFrameSource(queue: writer.queue, path: path, width: roundUp(width, multiple: 16), height: roundUp(height, multiple: 16), cachePathPrefix: nil, unpremultiplyAlpha: false) else {
            return
        }
        let frameDuration = 1.0 / Double(frameSource.frameRate)
        while true {
            if writer.isCancelled {
                break
            }
            if let frame = frameSource.takeFrame(draw: true) {
                if case .argb = frame.type {
                    let bytesPerRow = frame.bytesPerRow
                    
                    writer.add(with: { surface in
                        frame.data.withUnsafeBytes { bytes -> Void in
                            let sourceArgb = bytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                            if surface.bytesPerRow == bytesPerRow {
                                memcpy(surface.argb, sourceArgb, min(surface.length, bytes.count))
                            } else {
                                let copyBytesPerRow = min(surface.bytesPerRow, bytesPerRow)
                                for y in 0 ..< surface.height {
                                    memcpy(surface.argb.advanced(by: y * surface.bytesPerRow), sourceArgb.advanced(by: y * bytesPerRow), copyBytesPerRow)
                                }
                            }
                        }
                        return frameDuration
                    }, proposedWidth: frame.width, proposedHeight: frame.height, insertKeyframe: false)
                    
                    if firstFrameOnly {
                        break
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
    
    writer.queue.async(work)
}
