import LegacyComponents
import Display
import Postbox
import SwiftSignalKit
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
    
    func image(for time: CMTime, fps: Int, completion: @escaping (CIImage?) -> Void)
}

private func render(width: Int, height: Int, bytesPerRow: Int, data: Data, type: AnimationRendererFrameType) -> CIImage? {
    let calculatedBytesPerRow = (4 * Int(width) + 31) & (~31)
    assert(bytesPerRow == calculatedBytesPerRow)
    
    let image = generateImagePixel(CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, pixelGenerator: { _, pixelData, bytesPerRow in
        switch type {
            case .yuva:
                data.withUnsafeBytes { buffer -> Void in
                    guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return
                    }
                    decodeYUVAToRGBA(bytes, pixelData, Int32(width), Int32(height), Int32(bytesPerRow))
                }
            case .argb:
                data.withUnsafeBytes { buffer -> Void in
                    guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return
                    }
                    memcpy(pixelData, bytes, data.count)
                }
            case .dct:
                break
        }
    })

    if let image = image {
        return CIImage(image: image)
    } else {
        return nil
    }
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
    let durationPromise = Promise<Double>()
    
    var source: AnimatedStickerNodeSource?
    var frameQueue = Promise<QueueLocalObject<AnimatedStickerFrameQueue>?>()
    
    var frameCount: Int?
    var frameRate: Int?
    var totalDuration: Double?
        
    let queue = Queue()
    let disposables = DisposableSet()
    
    let imagePromise = Promise<UIImage>()
    
    init?(account: Account, entity: TGPhotoPaintStickerEntity) {
        let decoder = PostboxDecoder(buffer: MemoryBuffer(data: entity.document))
        if let file = decoder.decodeRootObject() as? TelegramMediaFile {
            self.account = account
            self.entity = entity
            self.file = file
            self.animated = file.isAnimatedSticker || file.isVideoSticker
            
            if file.isAnimatedSticker || file.isVideoSticker {
                self.source = AnimatedStickerResourceSource(account: account, resource: file.resource, isVideo: file.isVideoSticker)
                if let source = self.source {
                    let dimensions = self.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                    let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 384, height: 384))
                    self.disposables.add((source.cachedDataPath(width: Int(fittedDimensions.width), height: Int(fittedDimensions.height))
                        |> deliverOn(self.queue)).start(next: { [weak self] path, complete in
                        if let strongSelf = self, complete {
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                                let queue = strongSelf.queue
                                let frameSource = AnimatedStickerCachedFrameSource(queue: queue, data: data, complete: complete, notifyUpdated: {})!
                                strongSelf.frameCount = frameSource.frameCount
                                strongSelf.frameRate = frameSource.frameRate
                                
                                let duration = Double(frameSource.frameCount) / Double(frameSource.frameRate)
                                strongSelf.totalDuration = duration
                                
                                strongSelf.durationPromise.set(.single(duration))
                                
                                let frameQueue = QueueLocalObject<AnimatedStickerFrameQueue>(queue: queue, generate: {
                                    return AnimatedStickerFrameQueue(queue: queue, length: 1, source: frameSource)
                                })
                                strongSelf.frameQueue.set(.single(frameQueue))
                            }
                        }
                    }))
                }
            } else {
                self.disposables.add((chatMessageSticker(account: self.account, file: self.file, small: false, fetched: true, onlyFullSize: true, thumbnail: false, synchronousLoad: false)
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
        self.disposables.dispose()
    }
    
    var duration: Signal<Double, NoError> {
        return self.durationPromise.get()
    }
        
    var currentFrameIndex: Int?
   
    var cachedCIImage: CIImage?
    func image(for time: CMTime, fps: Int, completion: @escaping (CIImage?) -> Void) {
        if self.animated {
            let currentTime = CMTimeGetSeconds(time)
            
            self.disposables.add((self.frameQueue.get()
            |> take(1)
            |> deliverOn(self.queue)).start(next: { [weak self] frameQueue in
                guard let strongSelf = self else {
                    completion(nil)
                    return
                }

                guard let frameQueue = frameQueue, let duration = strongSelf.totalDuration, let frameCount = strongSelf.frameCount else {
                    completion(nil)
                    return
                }
                
                let relativeTime = currentTime - floor(currentTime / duration) * duration
                var t = relativeTime / duration
                t = max(0.0, t)
                t = min(1.0, t)
                
                let startFrame: Double = 0
                let endFrame = Double(frameCount)
                
                let frameOffset = Int(Double(startFrame) * (1.0 - t) + Double(endFrame - 1) * t)
                let lowerBound: Int = 0
                let upperBound = frameCount - 1
                let frameIndex = max(lowerBound, min(upperBound, frameOffset))
                
                let currentFrameIndex = strongSelf.currentFrameIndex
                if currentFrameIndex != frameIndex {
                    let previousFrameIndex = currentFrameIndex
                    strongSelf.currentFrameIndex = frameIndex
                    
                    var delta = 1
                    if let previousFrameIndex = previousFrameIndex {
                        delta = max(1, frameIndex - previousFrameIndex)
                    }
                    
                    let maybeFrame = frameQueue.syncWith { frameQueue -> AnimatedStickerFrame? in
                        var frame: AnimatedStickerFrame?
                        for i in 0 ..< delta {
                            frame = frameQueue.take(draw: i == delta - 1)
                        }
                        return frame
                    }
                    if let frame = maybeFrame {
                        let image = render(width: frame.width, height: frame.height, bytesPerRow: frame.bytesPerRow, data: frame.data, type: frame.type)
                        completion(image)
                        strongSelf.cachedCIImage = image
                    } else {
                        completion(nil)
                    }
                    frameQueue.with { frameQueue in
                        frameQueue.generateFramesIfNeeded()
                    }
                } else {
                    completion(strongSelf.cachedCIImage)
                }
            }))
        } else {
            self.queue.async {
                var image: CIImage?
                if let cachedImage = self.cachedCIImage {
                    image = cachedImage
                    completion(image)
                } else {
                    let _ = (self.imagePromise.get()
                    |> take(1)
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
    func image(for time: CMTime, fps: Int, completion: @escaping (CIImage?) -> Void) {
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
    private let account: Account?
    private let queue = Queue()

    private let entities: [LegacyPaintEntity]
    private let originalSize: CGSize
    private let cropRect: CGRect?
    
    public init(account: Account?, adjustments: TGMediaEditAdjustments) {
        self.account = account
        self.originalSize = adjustments.originalSize
        self.cropRect = adjustments.cropRect.isEmpty ? nil : adjustments.cropRect
        
        var entities: [LegacyPaintEntity] = []
        if let paintingData = adjustments.paintingData, let paintingEntities = paintingData.entities {
            for paintingEntity in paintingEntities {
                if let sticker = paintingEntity as? TGPhotoPaintStickerEntity {
                    if let account = account, let entity = LegacyPaintStickerEntity(account: account, entity: sticker) {
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
    
    public func duration() -> Signal<Double, NoError> {
        var durations: [Signal<Double, NoError>] = []
        for entity in self.entities {
            if let sticker = entity as? LegacyPaintStickerEntity, sticker.animated {
                durations.append(sticker.duration)
            }
        }
        
        func gcd(_ a: Int32, _ b: Int32) -> Int32 {
            let remainder = a % b
            if remainder != 0 {
                return gcd(b, remainder)
            } else {
                return b
            }
        }
        
        func lcm(_ x: Int32, _ y: Int32) -> Int32 {
            return x / gcd(x, y) * y
        }
        
        return combineLatest(durations)
        |> map { durations in
            var result: Double
            let minDuration: Double = 3.0
            if durations.count > 1 {
                let reduced = durations.reduce(1.0) { lhs, rhs -> Double in
                    return Double(lcm(Int32(lhs * 10.0), Int32(rhs * 10.0)))
                }
                result = min(6.0, Double(reduced) / 10.0)
            } else if let duration = durations.first {
                result = duration
            } else {
                result = minDuration
            }
            if result < minDuration {
                if result > 0 {
                    result = result * ceil(minDuration / result)
                } else {
                    result = minDuration
                }
            }
            return result
        }
    }
    
    public func entities(for time: CMTime, fps: Int, size: CGSize, completion: (([CIImage]?) -> Void)!) {
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
                    let index = i
                    entity.image(for: time, fps: fps, completion: { image in
                        if var image = image {
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
    public var captionPanelView: (() -> TGCaptionPanelView?)!
    public var presentStickersController: ((((Any?, Bool, UIView?, CGRect) -> Void)?) -> TGPhotoPaintStickersScreen?)!
    
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
