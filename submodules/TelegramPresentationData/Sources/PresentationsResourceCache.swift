import Foundation
import UIKit
import SwiftSignalKit

#if DEBUG
private final class CacheStats {
    var totalSize: Int = 0
    var reportSize: Int = 0
    
    func logImage(image: UIImage, added: Bool) {
        let sign = added ? 1 : -1
        
        self.totalSize += sign * Int(image.size.width * image.scale) * Int(image.size.height * image.scale) * 4
        if abs(self.totalSize - self.reportSize) >= 1024 * 1024 {
            self.reportSize = self.totalSize
            print("UI resource cache: \((self.totalSize) / (1024 * 1024)) MB")
        }
    }
}
private let cacheStats = Atomic<CacheStats>(value: CacheStats())
#endif

private final class PresentationsResourceCacheHolder {
    var images: [Int32: UIImage] = [:]
    var parameterImages: [PresentationResourceParameterKey: UIImage] = [:]
    
    deinit {
        #if DEBUG
        cacheStats.with { cacheStats in
            for (_, image) in self.images {
                cacheStats.logImage(image: image, added: false)
            }
            for (_, image) in self.parameterImages {
                cacheStats.logImage(image: image, added: false)
            }
        }
        #endif
    }
    
    func logAddedImage(image: UIImage) {
        #if DEBUG
        cacheStats.with { cacheStats in
            cacheStats.logImage(image: image, added: true)
        }
        #endif
    }
}

private final class PresentationsResourceAnyCacheHolder {
    var objects: [Int32: AnyObject] = [:]
    var parameterObjects: [PresentationResourceParameterKey: AnyObject] = [:]
}

public final class PresentationsResourceCache {
    private let imageCache = Atomic<PresentationsResourceCacheHolder>(value: PresentationsResourceCacheHolder())
    private let objectCache = Atomic<PresentationsResourceAnyCacheHolder>(value: PresentationsResourceAnyCacheHolder())
    
    public func image(_ key: Int32, _ theme: PresentationTheme, _ generate: (PresentationTheme) -> UIImage?) -> UIImage? {
        let result = self.imageCache.with { holder -> UIImage? in
            return holder.images[key]
        }
        if let result = result {
            return result
        } else {
            if let image = generate(theme) {
                self.imageCache.with { holder -> Void in
                    holder.images[key] = image
                    holder.logAddedImage(image: image)
                }
                return image
            } else {
                return nil
            }
        }
    }
    
    public func parameterImage(_ key: PresentationResourceParameterKey, _ theme: PresentationTheme, _ generate: (PresentationTheme) -> UIImage?) -> UIImage? {
        let result = self.imageCache.with { holder -> UIImage? in
            return holder.parameterImages[key]
        }
        if let result = result {
            return result
        } else {
            if let image = generate(theme) {
                self.imageCache.with { holder -> Void in
                    holder.parameterImages[key] = image
                    holder.logAddedImage(image: image)
                }
                return image
            } else {
                return nil
            }
        }
    }
    
    public func object(_ key: Int32, _ theme: PresentationTheme, _ generate: (PresentationTheme) -> AnyObject?) -> AnyObject? {
        let result = self.objectCache.with { holder -> AnyObject? in
            return holder.objects[key]
        }
        if let result = result {
            return result
        } else {
            if let object = generate(theme) {
                self.objectCache.with { holder -> Void in
                    holder.objects[key] = object
                }
                return object
            } else {
                return nil
            }
        }
    }
    
    public func parameterObject(_ key: PresentationResourceParameterKey, _ theme: PresentationTheme, _ generate: (PresentationTheme) -> AnyObject?) -> AnyObject? {
        let result = self.objectCache.with { holder -> AnyObject? in
            return holder.parameterObjects[key]
        }
        if let result = result {
            return result
        } else {
            if let object = generate(theme) {
                self.objectCache.with { holder -> Void in
                    holder.parameterObjects[key] = object
                }
                return object
            } else {
                return nil
            }
        }
    }
}
