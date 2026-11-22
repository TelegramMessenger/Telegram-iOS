import Foundation
import UIKit
import Metal
import Display

private func alignUp(size: Int, align: Int) -> Int {
    precondition(((align - 1) & align) == 0, "Align must be a power of two")

    let alignmentMask = align - 1
    return (size + alignmentMask) & ~alignmentMask
}

open class MetalImageLayer: CALayer {
    fileprivate final class TextureStoragePool {
        let width: Int
        let height: Int
        
        private var items: [TextureStorage.Content] = []
        
        init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }
        
        func recycle(content: TextureStorage.Content) {
            if self.items.count < 4 {
                self.items.append(content)
            } else {
                print("Warning: over-recycling texture storage")
            }
        }
        
        func take() -> TextureStorage.Content? {
            if self.items.isEmpty {
                return nil
            }
            return self.items.removeLast()
        }
    }
    
    fileprivate final class TextureStorage {
        final class Content {
            #if !targetEnvironment(simulator)
            let buffer: MTLBuffer
            #endif
            
            let width: Int
            let height: Int
            let bytesPerRow: Int
            let texture: MTLTexture
            
            init?(device: MTLDevice, width: Int, height: Int) {
                if #available(iOS 12.0, *) {
                    let bytesPerPixel = 4
                    let pixelRowAlignment = device.minimumLinearTextureAlignment(for: .bgra8Unorm)
                    let bytesPerRow = alignUp(size: width * bytesPerPixel, align: pixelRowAlignment)
                    
                    self.width = width
                    self.height = height
                    self.bytesPerRow = bytesPerRow
                    
                    #if targetEnvironment(simulator)
                    let textureDescriptor = MTLTextureDescriptor()
                    textureDescriptor.textureType = .type2D
                    textureDescriptor.pixelFormat = .bgra8Unorm
                    textureDescriptor.width = width
                    textureDescriptor.height = height
                    textureDescriptor.usage = [.renderTarget]
                    textureDescriptor.storageMode = .shared
                    
                    guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                        return nil
                    }
                    #else
                    guard let buffer = device.makeBuffer(length: bytesPerRow * height, options: MTLResourceOptions.storageModeShared) else {
                        return nil
                    }
                    self.buffer = buffer
                    
                    let textureDescriptor = MTLTextureDescriptor()
                    textureDescriptor.textureType = .type2D
                    textureDescriptor.pixelFormat = .bgra8Unorm
                    textureDescriptor.width = width
                    textureDescriptor.height = height
                    textureDescriptor.usage = [.renderTarget]
                    textureDescriptor.storageMode = buffer.storageMode
                    
                    guard let texture = buffer.makeTexture(descriptor: textureDescriptor, offset: 0, bytesPerRow: bytesPerRow) else {
                        return nil
                    }
                    #endif
                    
                    self.texture = texture
                } else {
                    return nil
                }
            }
        }
        
        private weak var pool: TextureStoragePool?
        let content: Content
        private var isInvalidated: Bool = false
        
        init(pool: TextureStoragePool, content: Content) {
            self.pool = pool
            self.content = content
        }
        
        deinit {
            if !self.isInvalidated {
                self.pool?.recycle(content: self.content)
            }
        }
        
        func createCGImage() -> CGImage? {
            if self.isInvalidated {
                return nil
            }
            self.isInvalidated = true
            
            #if targetEnvironment(simulator)
            guard let data = NSMutableData(capacity: self.content.bytesPerRow * self.content.height) else {
                return nil
            }
            data.length = self.content.bytesPerRow * self.content.height
            self.content.texture.getBytes(data.mutableBytes, bytesPerRow: self.content.bytesPerRow, bytesPerImage: self.content.bytesPerRow * self.content.height, from: MTLRegion(origin: MTLOrigin(), size: MTLSize(width: self.content.width, height: self.content.height, depth: 1)), mipmapLevel: 0, slice: 0)
            
            guard let dataProvider = CGDataProvider(data: data as CFData) else {
                return nil
            }
            #else
            let content = self.content
            let pool = self.pool
            guard let dataProvider = CGDataProvider(data: Data(bytesNoCopy: self.content.buffer.contents(), count: self.content.buffer.length, deallocator: .custom { [weak pool] _, _ in
                guard let pool = pool else {
                    return
                }
                pool.recycle(content: content)
            }) as CFData) else {
                return nil
            }
            #endif

            guard let image = CGImage(
                width: Int(self.content.width),
                height: Int(self.content.height),
                bitsPerComponent: 8,
                bitsPerPixel: 8 * 4,
                bytesPerRow: self.content.bytesPerRow,
                space: DeviceGraphicsContextSettings.shared.colorSpace,
                bitmapInfo: DeviceGraphicsContextSettings.shared.transparentBitmapInfo,
                provider: dataProvider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            ) else {
                return nil
            }
            
            return image
        }
    }
    
    public final class Drawable {
        private weak var renderer: Renderer?
        fileprivate let textureStorage: TextureStorage
        public var texture: MTLTexture {
            return self.textureStorage.content.texture
        }
        
        fileprivate init(renderer: Renderer, textureStorage: TextureStorage) {
            self.renderer = renderer
            self.textureStorage = textureStorage
        }
        
        public func present(completion: @escaping () -> Void) {
            self.renderer?.present(drawable: self)
            completion()
        }
    }
    
    public final class Renderer {
        public var device: MTLDevice?
        private var storagePool: TextureStoragePool?
        
        public var imageUpdated: ((CGImage?) -> Void)?
        
        public var drawableSize: CGSize = CGSize() {
            didSet {
                if self.drawableSize != oldValue {
                    if !self.drawableSize.width.isZero && !self.drawableSize.height.isZero {
                        self.storagePool = TextureStoragePool(width: Int(self.drawableSize.width), height: Int(self.drawableSize.height))
                    } else {
                        self.storagePool = nil
                    }
                }
            }
        }
        
        public func nextDrawable() -> Drawable? {
            guard let device = self.device else {
                return nil
            }
            guard let storagePool = self.storagePool else {
                return nil
            }

            if let content = storagePool.take() {
                return Drawable(renderer: self, textureStorage: TextureStorage(pool: storagePool, content: content))
            } else {
                guard let content = TextureStorage.Content(device: device, width: storagePool.width, height: storagePool.height) else {
                    return nil
                }
                return Drawable(renderer: self, textureStorage: TextureStorage(pool: storagePool, content: content))
            }
        }
        
        fileprivate func present(drawable: Drawable) {
            if let imageUpdated = self.imageUpdated {
                imageUpdated(drawable.textureStorage.createCGImage())
            }
        }
    }
    
    public let renderer = Renderer()
    
    override public init() {
        super.init()
        
        self.renderer.imageUpdated = { [weak self] image in
            self?.contents = image
        }
    }
    
    override public init(layer: Any) {
        preconditionFailure()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func action(forKey event: String) -> CAAction? {
        return nullAction
    }
}

open class MetalImageView: UIView {
    public static override var layerClass: AnyClass {
        return MetalImageLayer.self
    }
}
