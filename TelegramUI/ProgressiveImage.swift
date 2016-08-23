import Foundation
import UIKit
import SwiftSignalKit
import Display
import ImageIO

public final class ProgressiveImage {
    let backgroundImage: UIImage?
    let image: UIImage?
    
    public init(backgroundImage: UIImage?, image: UIImage?) {
        self.backgroundImage = backgroundImage
        self.image = image
    }
}

public func progressiveImage(dataSignal: Signal<Data?, NoError>, size: Int, mapping: @escaping (CGImage) -> UIImage) -> Signal<UIImage?, NoError> {
    return Signal { subscriber in
        let imageSource = CGImageSourceCreateIncremental(nil)
        var lastSize = 0
        
        return dataSignal.start(next: { data in
            if let data = data {
                if data.count >= lastSize + 24 * 1024 || (lastSize != data.count && data.count >= size) {
                    lastSize = data.count
                    
                    let copyData = data.withUnsafeBytes { bytes -> CFData in
                        return CFDataCreate(nil, bytes, data.count)
                    }
                    CGImageSourceUpdateData(imageSource, copyData, data.count >= size)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        subscriber.putNext(mapping(image))
                    } else {
                        subscriber.putNext(nil)
                    }
                    if data.count >= size {
                        subscriber.putCompletion()
                    }
                }
            } else {
                subscriber.putNext(nil)
            }
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            subscriber.putCompletion()
        })
    }
}
