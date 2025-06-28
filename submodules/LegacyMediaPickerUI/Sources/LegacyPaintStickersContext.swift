import LegacyComponents
import UIKit
import Display
import Postbox
import SwiftSignalKit
import TelegramCore
import AccountContext
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import YuvConversion
import StickerResources
import SolidRoundedButtonNode
import MediaEditor
import DrawingUI
import TelegramPresentationData
import AnimatedCountLabelNode
import CoreMedia

protocol LegacyPaintEntity {
    var position: CGPoint { get }
    var scale: CGFloat { get }
    var angle: CGFloat { get }
    var baseSize: CGSize? { get }
    var mirrored: Bool { get }
    
    func image(for time: CMTime, fps: Int, completion: @escaping (CIImage?) -> Void)
}

private func render(width: Int, height: Int, bytesPerRow: Int, data: Data, type: AnimationRendererFrameType, tintColor: UIColor?) -> CIImage? {
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

    if var image = image {
        if let tintColor, let tintedImage = generateTintedImage(image: image, color: tintColor) {
            image = tintedImage
        }
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
        return self.entity.rotation
    }
    
    var baseSize: CGSize? {
        return self.entity.baseSize
    }
    
    var mirrored: Bool {
        return self.entity.mirrored
    }
    
    let postbox: Postbox
    let file: TelegramMediaFile?
    let entity: DrawingStickerEntity
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
    
    init(postbox: Postbox, entity: DrawingStickerEntity) {
        self.postbox = postbox
        self.entity = entity
        self.animated = entity.isAnimated

        switch entity.content {
        case let .file(fileReference, _):
            let file = fileReference.media
            self.file = file
            if file.isAnimatedSticker || file.isVideoSticker || file.mimeType == "video/webm" {
                self.source = AnimatedStickerResourceSource(postbox: postbox, resource: file.resource, isVideo: file.isVideoSticker || file.mimeType == "video/webm")
                if let source = self.source {
                    let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
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
                self.disposables.add((chatMessageSticker(postbox: self.postbox, userLocation: .other, file: file, small: false, fetched: true, onlyFullSize: true, thumbnail: false, synchronousLoad: false)
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
        case let .image(image, _):
            self.file = nil
            self.imagePromise.set(.single(image))
        case .animatedImage, .video, .dualVideoReference, .message, .gift:
            self.file = nil
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
            
            var tintColor: UIColor?
            if let file = self.file, file.isCustomTemplateEmoji {
                tintColor = .white
            }
            
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
                        let image = render(width: frame.width, height: frame.height, bytesPerRow: frame.bytesPerRow, data: frame.data, type: frame.type, tintColor: tintColor)
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
        return self.entity.rotation
    }
    
    var baseSize: CGSize? {
        return nil
    }
    
    var mirrored: Bool {
        return false
    }

    let entity: DrawingTextEntity

    init(entity: DrawingTextEntity) {
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

private class LegacyPaintSimpleShapeEntity: LegacyPaintEntity {
    var position: CGPoint {
        return self.entity.position
    }

    var scale: CGFloat {
        return 1.0
    }

    var angle: CGFloat {
        return self.entity.rotation
    }
    
    var baseSize: CGSize? {
        return self.entity.size
    }
    
    var mirrored: Bool {
        return false
    }

    let entity: DrawingSimpleShapeEntity

    init(entity: DrawingSimpleShapeEntity) {
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

private class LegacyPaintBubbleEntity: LegacyPaintEntity {
    var position: CGPoint {
        return self.entity.position
    }

    var scale: CGFloat {
        return 1.0
    }

    var angle: CGFloat {
        return self.entity.rotation
    }
    
    var baseSize: CGSize? {
        return self.entity.size
    }
    
    var mirrored: Bool {
        return false
    }

    let entity: DrawingBubbleEntity

    init(entity: DrawingBubbleEntity) {
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

private class LegacyPaintVectorEntity: LegacyPaintEntity {
    var position: CGPoint {
        return CGPoint(x: self.entity.drawingSize.width * 0.5, y: self.entity.drawingSize.height * 0.5)
    }

    var scale: CGFloat {
        return 1.0
    }

    var angle: CGFloat {
        return 0.0
    }
    
    var baseSize: CGSize? {
        return self.entity.drawingSize
    }
    
    var mirrored: Bool {
        return false
    }

    let entity: DrawingVectorEntity

    init(entity: DrawingVectorEntity) {
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
    private let postbox: Postbox?
    private let queue = Queue()

    private let entities: [LegacyPaintEntity]
    private let originalSize: CGSize
    private let cropRect: CGRect?
    
    private let isAvatar: Bool
    
    public init(postbox: Postbox?, adjustments: TGMediaEditAdjustments) {
        self.postbox = postbox
        self.originalSize = adjustments.originalSize
        self.cropRect = adjustments.cropRect.isEmpty ? nil : adjustments.cropRect
        self.isAvatar = ((adjustments as? TGVideoEditAdjustments)?.documentId ?? 0) != 0
        
        var renderEntities: [LegacyPaintEntity] = []
        if let paintingData = adjustments.paintingData, let entitiesData = paintingData.entitiesData {
            let entities = decodeDrawingEntities(data: entitiesData)
            for entity in entities {
                if let sticker = entity as? DrawingStickerEntity, let postbox {
                    renderEntities.append(LegacyPaintStickerEntity(postbox: postbox, entity: sticker))
                } else if let text = entity as? DrawingTextEntity {
                    renderEntities.append(LegacyPaintTextEntity(entity: text))
                    if let renderSubEntities = text.renderSubEntities, let postbox {
                        for entity in renderSubEntities {
                            if let entity = entity as? DrawingStickerEntity {
                                renderEntities.append(LegacyPaintStickerEntity(postbox: postbox, entity: entity))
                            }
                        }
                    }
                } else if let simpleShape = entity as? DrawingSimpleShapeEntity {
                    renderEntities.append(LegacyPaintSimpleShapeEntity(entity: simpleShape))
                } else if let bubble = entity as? DrawingBubbleEntity {
                    renderEntities.append(LegacyPaintBubbleEntity(entity: bubble))
                } else if let vector = entity as? DrawingVectorEntity {
                    renderEntities.append(LegacyPaintVectorEntity(entity: vector))
                }
            }
        }
        self.entities = renderEntities
        
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
        
        func gcd(_ a: Int64, _ b: Int64) -> Int64 {
            let remainder = a % b
            if remainder != 0 {
                return gcd(b, remainder)
            } else {
                return b
            }
        }
        
        func lcm(_ x: Int64, _ y: Int64) -> Int64 {
            let x = max(x, 1)
            let y = max(y, 1)
            return x / gcd(x, y) * y
        }
                
        return combineLatest(durations)
        |> map { durations in
            var result: Double
            let minDuration: Double = 3.0
            if durations.count > 1 {
                let reduced = durations.reduce(1.0) { lhs, rhs -> Double in
                    return Double(lcm(Int64(lhs * 100.0), Int64(rhs * 100.0)))
                }
                result = min(6.0, Double(reduced) / 10.0)
            } else if let duration = durations.first {
                result = duration
            } else {
                result = minDuration
            }
            if result < minDuration && !self.isAvatar {
                if result > 0 {
                    result = result * ceil(minDuration / result)
                } else {
                    result = minDuration
                }
            }
            return result
        }
    }
    
    public func entities(for time: CMTime, fps: Int, size: CGSize, completion: @escaping ([CIImage]) -> Void) {
        let entities = self.entities
        let maxSide = max(size.width, size.height)
        let paintingScale = maxSide / 1920.0
        
        self.queue.async {
            if entities.isEmpty {
                completion([])
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
                            transform = transform.rotated(by: CGFloat.pi * 2.0 - entity.angle)
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
    public var captionPanelView: (() -> TGCaptionPanelView?)?
    public var editCover: ((CGSize, @escaping (UIImage) -> Void) -> Void)?
    
    private let context: AccountContext
    
    public init(context: AccountContext) {
        self.context = context
    }
    
    class LegacyDrawingAdapter: NSObject, TGPhotoDrawingAdapter {
        let drawingView: TGPhotoDrawingView
        let drawingEntitiesView: TGPhotoDrawingEntitiesView
        let selectionContainerView: UIView
        let contentWrapperView: UIView
        let interfaceController: TGPhotoDrawingInterfaceController
        
        init(context: AccountContext, size: CGSize, originalSize: CGSize, isVideo: Bool, isAvatar: Bool, entitiesView: (UIView & TGPhotoDrawingEntitiesView)?) {
            let interfaceController = DrawingScreen(context: context, size: size, originalSize: originalSize, isVideo: isVideo, isAvatar: isAvatar, drawingView: nil, entitiesView: entitiesView, selectionContainerView: nil)
            self.interfaceController = interfaceController
            self.drawingView = interfaceController.drawingView
            self.drawingEntitiesView = interfaceController.entitiesView
            self.selectionContainerView = interfaceController.selectionContainerView
            self.contentWrapperView = interfaceController.contentWrapperView
            
            super.init()
        }
    }
    
    public func drawingAdapter(_ size: CGSize, originalSize: CGSize, isVideo: Bool, isAvatar: Bool, entitiesView: (UIView & TGPhotoDrawingEntitiesView)?) -> TGPhotoDrawingAdapter {
        return LegacyDrawingAdapter(context: self.context, size: size, originalSize: originalSize, isVideo: isVideo, isAvatar: isAvatar, entitiesView: entitiesView)
    }
    
    public func solidRoundedButton(_ title: String, action: @escaping () -> Void) -> UIView & TGPhotoSolidRoundedButtonView {
        let theme = SolidRoundedButtonTheme(theme: self.context.sharedContext.currentPresentationData.with { $0 }.theme)
        let button = SolidRoundedButtonView(title: title, theme: theme, height: 50.0, cornerRadius: 10.0)
        button.pressed = action
        return button
    }
    
    public func sendStarsButtonAction(_ action: @escaping () -> Void) -> any UIView & TGPhotoSendStarsButtonView {
        let button = SendStarsButtonView()
        button.pressed = action
        return button
    }
    
    public func drawingEntitiesView(with size: CGSize) -> UIView & TGPhotoDrawingEntitiesView {
        let view = DrawingEntitiesView(context: self.context, size: size)
        return view
    }
}

private class SendStarsButtonView: HighlightTrackingButton, TGPhotoSendStarsButtonView {
    private let backgroundView: UIView
    private let textNode: ImmediateAnimatedCountLabelNode
    
    fileprivate var pressed: (() -> Void)?
    
    override init(frame: CGRect) {
        self.backgroundView = UIView()
        self.backgroundView.isUserInteractionEnabled = false
        
        self.textNode = ImmediateAnimatedCountLabelNode()
        self.textNode.isUserInteractionEnabled = false
        
        super.init(frame: frame)
        
        self.addSubview(self.backgroundView)
        self.addSubview(self.textNode.view)
        
        self.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                self.backgroundView.layer.removeAnimation(forKey: "opacity")
                self.backgroundView.alpha = 0.4
                self.textNode.layer.removeAnimation(forKey: "opacity")
                self.textNode.alpha = 0.4
            } else {
                self.backgroundView.alpha = 1.0
                self.backgroundView.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                self.textNode.alpha = 1.0
                self.textNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        
        self.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    deinit {
        print()
    }
    
    @objc private func buttonPressed() {
        self.pressed?()
    }
    
    func updateFrame(_ frame: CGRect) {
        let transition: ContainedViewLayoutTransition
        if self.frame.width.isZero {
            transition = .immediate
        } else {
            transition = .animated(duration: 0.4, curve: .spring)
        }
        transition.updateFrame(view: self, frame: frame)
    }
    
    func updateCount(_ count: Int64) -> CGSize {
        let text = "\(count)"
        let transition: ContainedViewLayoutTransition
        if self.backgroundView.frame.width.isZero {
            transition = .immediate
        } else {
            transition = .animated(duration: 0.4, curve: .spring)
        }
        
        var segments: [AnimatedCountLabelNode.Segment] = []
        let font = Font.with(size: 17.0, design: .round, weight: .semibold, traits: .monospacedNumbers)
        let badgeString = NSMutableAttributedString(string: "⭐️ ", font: font, textColor: .white)
        if let range = badgeString.string.range(of: "⭐️") {
            badgeString.addAttribute(.attachment, value: PresentationResourcesChat.chatPlaceholderStarIcon(defaultDarkPresentationTheme)!, range: NSRange(range, in: badgeString.string))
            badgeString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: badgeString.string))
        }
        segments.append(.text(0, badgeString))
        for char in text {
            if let intValue = Int(String(char)) {
                segments.append(.number(intValue, NSAttributedString(string: String(char), font: font, textColor: .white)))
            }
        }
        
        self.textNode.segments = segments
        
        let buttonInset: CGFloat = 14.0
        let textSize = self.textNode.updateLayout(size: CGSize(width: 100.0, height: 100.0), animated: transition.isAnimated)
        let width = textSize.width + buttonInset * 2.0
        let buttonSize = CGSize(width: width, height: 45.0)
        let titleOffset: CGFloat = 0.0
        
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((width - textSize.width) / 2.0) + titleOffset, y: floorToScreenPixels((buttonSize.height - textSize.height) / 2.0)), size: textSize))
        
        let backgroundSize = CGSize(width: width - 11.0, height: 33.0)
        transition.updateFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((width - backgroundSize.width) / 2.0), y: floorToScreenPixels((buttonSize.height - backgroundSize.height) / 2.0)), size: backgroundSize))
        self.backgroundView.layer.cornerRadius = backgroundSize.height / 2.0
        self.backgroundView.backgroundColor = UIColor(rgb: 0x007aff)
        
        return buttonSize;
    }
}

#if SWIFT_PACKAGE
extension SolidRoundedButtonView: TGPhotoSolidRoundedButtonView {
    public func updateWidth(_ width: CGFloat) {
        let _ = self.updateLayout(width: width, transition: .immediate)
    }
}
#else
extension SolidRoundedButtonView: @retroactive TGPhotoSolidRoundedButtonView {
    public func updateWidth(_ width: CGFloat) {
        let _ = self.updateLayout(width: width, transition: .immediate)
    }
}
#endif
