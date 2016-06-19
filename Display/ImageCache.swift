import Foundation

/*private final class ImageCacheData {
    let size: CGSize
    let bytesPerRow: Int
    var data: NSPurgeableData
    
    var isDiscarded: Bool {
        return self.data.isContentDiscarded()
    }
    
    var image: UIImage? {
        if self.data.beginContentAccess() {
            return self.createImage()
        }
        return nil
    }
    
    init(size: CGSize, generator: (CGContext) -> Void, takenImage: @noescape(UIImage) -> Void) {
        self.size = size
        
        self.bytesPerRow = (4 * Int(size.width) + 15) & (~15)
        self.data = NSPurgeableData(length: self.bytesPerRow * Int(size.height))!
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.PremultipliedFirst.rawValue | CGBitmapInfo.ByteOrder32Little.rawValue
        
        if let context = CGBitmapContextCreate(self.data.mutableBytes, Int(size.width), Int(size.height), 8, bytesPerRow, colorSpace, bitmapInfo)
        {
            CGContextTranslateCTM(context, size.width / 2.0, size.height / 2.0)
            CGContextScaleCTM(context, 1.0, -1.0)
            CGContextTranslateCTM(context, -size.width / 2.0, -size.height / 2.0)
            
            UIGraphicsPushContext(context)
            
            generator(context)
            
            UIGraphicsPopContext()
        }
        
        takenImage(self.createImage())
    }
    
    private func createImage() -> UIImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        
        let unmanagedData = withUnsafePointer(&self.data, { pointer in
            return Unmanaged<NSPurgeableData>.fromOpaque(COpaquePointer(pointer))
        })
        unmanagedData.retain()
        let dataProvider = CGDataProviderCreateWithData(UnsafeMutablePointer<Void>(unmanagedData.toOpaque()), self.data.bytes, self.bytesPerRow, { info, _, _ in
            let unmanagedData = Unmanaged<NSPurgeableData>.fromOpaque(COpaquePointer(info))
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), {
                unmanagedData.takeUnretainedValue().endContentAccess()
                unmanagedData.release()
            })
        })
        
        let image = CGImageCreate(Int(self.size.width), Int(self.size.height), 8, 32, self.bytesPerRow, colorSpace, CGBitmapInfo(rawValue: bitmapInfo), dataProvider, nil, false, CGColorRenderingIntent(rawValue: 0)!)
        
        let result = UIImage(CGImage: image!)
        return result
    }
}

private final class ImageCacheResidentImage {
    let key: String
    let image: UIImage
    var accessIndex: Int
    
    init(key: String, image: UIImage, accessIndex: Int) {
        self.key = key
        self.image = image
        self.accessIndex = accessIndex
    }
}

public final class ImageCache {
    let maxResidentSize: Int
    var mutex = pthread_mutex_t()
    
    private var imageDatas: [String : ImageCacheData] = [:]
    private var residentImages: [String : ImageCacheResidentImage] = [:]
    var nextAccessIndex = 1
    var residentImagesSize = 0
    
    public init(maxResidentSize: Int) {
        self.maxResidentSize = maxResidentSize
        pthread_mutex_init(&self.mutex, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&self.mutex)
    }
    
    public func addImageForKey(key: String, size: CGSize, generator: CGContextRef -> Void) {
        var image: UIImage?
        let imageData = ImageCacheData(size: size, generator: generator, takenImage: { image = $0 })
        
        pthread_mutex_lock(&self.mutex)
        self.imageDatas[key] = imageData
        self.addResidentImage(image!, forKey: key)
        pthread_mutex_unlock(&self.mutex)
    }
    
    public func imageForKey(key: String) -> UIImage? {
        var image: UIImage?
        
        pthread_mutex_lock(&self.mutex);
        if let residentImage = self.residentImages[key] {
            image = residentImage.image
            self.nextAccessIndex += 1
            residentImage.accessIndex = self.nextAccessIndex
        } else {
            if let imageData = self.imageDatas[key] {
                if let takenImage = imageData.image {
                    image = takenImage
                    self.addResidentImage(takenImage, forKey: key)
                } else {
                    self.imageDatas.removeValueForKey(key)
                }
            }
        }
        pthread_mutex_unlock(&self.mutex)
        
        return image
    }
    
    private func addResidentImage(image: UIImage, forKey key: String) {
        let imageSize = Int(image.size.width * image.size.height * image.scale) * 4

        if self.residentImagesSize + imageSize > self.maxResidentSize {
            let sizeToRemove = self.residentImagesSize - (self.maxResidentSize - imageSize)
            let sortedImages = self.residentImages.values.sort({ $0.accessIndex < $1.accessIndex })
        
            var removedSize = 0
            var i = sortedImages.count - 1
            while i >= 0 && removedSize < sizeToRemove {
                let currentImage = sortedImages[i]
                let currentImageSize = Int(currentImage.image.size.width * currentImage.image.size.height * currentImage.image.scale) * 4
                removedSize += currentImageSize
                self.residentImages.removeValueForKey(currentImage.key)
                i -= 1
            }
            
            self.residentImagesSize = max(0, self.residentImagesSize - removedSize)
        }
        
        self.residentImagesSize += imageSize
        self.nextAccessIndex += 1
        self.residentImages[key] = ImageCacheResidentImage(key: key, image: image, accessIndex: self.nextAccessIndex)
    }
}*/
