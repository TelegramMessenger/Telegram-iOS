import LegacyComponents
import Display
import Postbox
import SwiftSignalKit
import SyncCore
import TelegramCore
import AccountContext
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import YuvConversion
import StickerResources

protocol LegacyPaintEntity {
    var position: CGPoint { get }
    var scale: CGFloat { get }
    var angle: CGFloat { get }
    var baseSize: CGSize? { get }
    var mirrored: Bool { get }
    
    func image(for time: CMTime, completion: @escaping (CIImage?) -> Void)
}

private class LegacyPaintStickerEntity: LegacyPaintEntity {
    var position: CGPoint {
        return self.entity.position
    }
    
    var scale: CGFloat {
        return self.entity.scale
    }
    
    var angle: CGFloat {
        return self.entity.angle
    }
    
    var baseSize: CGSize? {
        return self.entity.baseSize
    }
    
    var mirrored: Bool {
        return self.entity.mirrored
    }
    
    let account: Account
    let file: TelegramMediaFile
    let entity: TGPhotoPaintStickerEntity
    let animated: Bool
    
    var source: AnimatedStickerNodeSource?
    var frameSource: AnimatedStickerFrameSource?
    var frameQueue: QueueLocalObject<AnimatedStickerFrameQueue>?
    
    let queue = Queue()
    let disposable = MetaDisposable()
    
    let imagePromise = Promise<UIImage>()
    
    init?(account: Account, entity: TGPhotoPaintStickerEntity) {
        let decoder = PostboxDecoder(buffer: MemoryBuffer(data: entity.document))
        if let file = decoder.decodeRootObject() as? TelegramMediaFile {
            self.account = account
            self.entity = entity
            self.file = file
            self.animated = file.isAnimatedSticker
            
            if file.isAnimatedSticker {
                self.source = AnimatedStickerResourceSource(account: account, resource: file.resource)
                if let source = self.source {
                    let dimensions = self.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                    let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 256.0, height: 256.0))
                    self.disposable.set((source.cachedDataPath(width: Int(fittedDimensions.width), height: Int(fittedDimensions.height))
                        |> deliverOn(self.queue)).start(next: { [weak self] path, complete in
                        if let strongSelf = self, complete {
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                                let queue = strongSelf.queue
                                let frameSource = AnimatedStickerCachedFrameSource(queue: queue, data: data, complete: complete, notifyUpdated: {})!
                                
                                let frameQueue = QueueLocalObject<AnimatedStickerFrameQueue>(queue: queue, generate: {
                                    return AnimatedStickerFrameQueue(queue: queue, length: 1, source: frameSource)
                                })
                                
                                strongSelf.frameQueue = frameQueue
                                strongSelf.frameSource = frameSource
                            }
                        }
                    }))
                }
            } else {
                self.disposable.set((chatMessageSticker(account: self.account, file: self.file, small: false, fetched: true, onlyFullSize: true, thumbnail: false, synchronousLoad: false)
                |> deliverOn(self.queue)).start(next: { [weak self] generator in
                    if let strongSelf = self {
                        let context = generator(TransformImageArguments(corners: ImageCorners(), imageSize: entity.baseSize, boundingSize: entity.baseSize, intrinsicInsets: UIEdgeInsets()))
                        let image = context?.generateImage()
                        if let image = image {
                            strongSelf.imagePromise.set(.single(image))
                        }
                    }
                }))
            }
        } else {
            return nil
        }
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    private func render(width: Int, height: Int, bytesPerRow: Int, data: Data, type: AnimationRendererFrameType) -> CIImage? {
        let calculatedBytesPerRow = (4 * Int(width) + 15) & (~15)
        assert(bytesPerRow == calculatedBytesPerRow)
        
        let image = generateImagePixel(CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, pixelGenerator: { _, pixelData, bytesPerRow in
            switch type {
                case .yuva:
                    data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                        decodeYUVAToRGBA(bytes, pixelData, Int32(width), Int32(height), Int32(bytesPerRow))
                    }
                case .argb:
                    data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                        memcpy(pixelData, bytes, data.count)
                    }
            }
        })
    
        if let image = image {
            return CIImage(image: image)
        } else {
            return nil
        }
    }
    
    var cachedCIImage: CIImage?
    func image(for time: CMTime, completion: @escaping (CIImage?) -> Void) {
        if self.animated {
            let frameQueue = self.frameQueue
            self.queue.async {
                guard let frameQueue = frameQueue else {
                    completion(nil)
                    return
                }
                let maybeFrame = frameQueue.syncWith { frameQueue in
                    return frameQueue.take()
                }
                if let maybeFrame = maybeFrame, let frame = maybeFrame {
                    let image = self.render(width: frame.width, height: frame.height, bytesPerRow: frame.bytesPerRow, data: frame.data, type: frame.type)
                    completion(image)
                } else {
                    completion(nil)
                }
                frameQueue.with { frameQueue in
                    frameQueue.generateFramesIfNeeded()
                }
            }
        } else {
            self.queue.async {
                var image: CIImage?
                if let cachedImage = self.cachedCIImage {
                    image = cachedImage
                    completion(image)
                } else {
                    let _ = (self.imagePromise.get()
                    |> deliverOn(self.queue)).start(next: { [weak self] image in
                        if let strongSelf = self {
                            strongSelf.cachedCIImage = CIImage(image: image)
                            completion(strongSelf.cachedCIImage)
                        }
                    })
                }
            }
        }
    }
}

private class LegacyPaintTextEntity: LegacyPaintEntity {    
    var position: CGPoint {
        return self.entity.position
    }

    var scale: CGFloat {
        return self.entity.scale
    }

    var angle: CGFloat {
        return self.entity.angle
    }
    
    var baseSize: CGSize? {
        return nil
    }
    
    var mirrored: Bool {
        return false
    }

    let entity: TGPhotoPaintTextEntity

    init(entity: TGPhotoPaintTextEntity) {
        self.entity = entity
    }

    var cachedCIImage: CIImage?
    func image(for time: CMTime, completion: @escaping (CIImage?) -> Void) {
        var image: CIImage?
        if let cachedImage = self.cachedCIImage {
            image = cachedImage
        } else if let renderImage = entity.renderImage {
            image = CIImage(image: renderImage)
            self.cachedCIImage = image
        }
        completion(image)
    }
}

public final class LegacyPaintEntityRenderer: NSObject, TGPhotoPaintEntityRenderer {
    private let account: Account
    private let queue = Queue()

    private let entities: [LegacyPaintEntity]
    private let originalSize: CGSize
    private let cropRect: CGRect?
    
    public init(account: Account, adjustments: TGMediaEditAdjustments) {
        self.account = account
        self.originalSize = adjustments.originalSize
        self.cropRect = adjustments.cropRect.isEmpty ? nil : adjustments.cropRect
        
        var entities: [LegacyPaintEntity] = []
        if let paintingData = adjustments.paintingData, let paintingEntities = paintingData.entities {
            for paintingEntity in paintingEntities {
                if let sticker = paintingEntity as? TGPhotoPaintStickerEntity {
                    if let entity = LegacyPaintStickerEntity(account: account, entity: sticker) {
                        entities.append(entity)
                    }
                } else if let text = paintingEntity as? TGPhotoPaintTextEntity {
                    entities.append(LegacyPaintTextEntity(entity: text))
                }
            }
        }
        self.entities = entities
        
        super.init()
    }
    
    deinit {
        
    }
    
    public func entities(for time: CMTime, size: CGSize, completion: (([CIImage]?) -> Void)!) {
        let entities = self.entities
        let maxSide = max(size.width, size.height)
        let paintingScale = maxSide / 1920.0
        
        self.queue.async {
            if entities.isEmpty {
                completion(nil)
            } else {
                let count = Atomic<Int>(value: 1)
                let images = Atomic<[(CIImage, Int)]>(value: [])
                let maybeFinalize = {
                    let count = count.modify { current -> Int in
                        return current - 1
                    }
                    if count == 0 {
                        let sortedImages = images.with({ $0 }).sorted(by: { $0.1 < $1.1 }).map({ $0.0 })
                        completion(sortedImages)
                    }
                }
                var i = 0
                for entity in entities {
                    let _ = count.modify { current -> Int in
                        return current + 1
                    }
                    entity.image(for: time, completion: { image in
                        if var image = image {
                            let index = i
                            var transform = CGAffineTransform(translationX: -image.extent.midX, y: -image.extent.midY)
                            image = image.transformed(by: transform)
                            
                            var scale = entity.scale * paintingScale
                            if let baseSize = entity.baseSize {
                                scale *= baseSize.width / image.extent.size.width
                            }
                        
                            transform = CGAffineTransform(translationX: entity.position.x * paintingScale, y: size.height - entity.position.y * paintingScale)
                            transform = transform.rotated(by: CGFloat.pi * 2 - entity.angle)
                            transform = transform.scaledBy(x: scale, y: scale)
                            if entity.mirrored {
                                transform = transform.scaledBy(x: -1.0, y: 1.0)
                            }
                                                        
                            image = image.transformed(by: transform)
                            let _ = images.modify { current in
                                var updated = current
                                updated.append((image, index))
                                return updated
                            }
                        }
                        maybeFinalize()
                    })
                    i += 1
                }
                maybeFinalize()
            }
        }
    }
}

public final class LegacyPaintStickersContext: NSObject, TGPhotoPaintStickersContext {
    public var presentStickersController: ((((Any?, Bool, UIView?, CGRect) -> Void)?) -> Void)!
    
    private let context: AccountContext
    
    public init(context: AccountContext) {
        self.context = context
    }
    
    public func documentId(forDocument document: Any!) -> Int64 {
        if let data = document as? Data{
            let decoder = PostboxDecoder(buffer: MemoryBuffer(data: data))
            if let file = decoder.decodeRootObject() as? TelegramMediaFile {
                return file.fileId.id
            } else {
                return 0
            }
        } else {
            return 0
        }
    }
    
    public func maskDescription(forDocument document: Any!) -> TGStickerMaskDescription? {
        if let data = document as? Data{
            let decoder = PostboxDecoder(buffer: MemoryBuffer(data: data))
            if let file = decoder.decodeRootObject() as? TelegramMediaFile {
                for attribute in file.attributes {
                    if case let .Sticker(_, _, maskData) = attribute {
                        if let maskData = maskData {
                            return TGStickerMaskDescription(n: maskData.n, point: CGPoint(x: maskData.x, y: maskData.y), zoom: CGFloat(maskData.zoom))
                        } else {
                            return nil
                        }
                    }
                }
                return nil
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    public func stickerView(forDocument document: Any!) -> (UIView & TGPhotoPaintStickerRenderView)! {
        if let data = document as? Data{
            let decoder = PostboxDecoder(buffer: MemoryBuffer(data: data))
            if let file = decoder.decodeRootObject() as? TelegramMediaFile {
                return LegacyPaintStickerView(context: self.context, file: file)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
}
