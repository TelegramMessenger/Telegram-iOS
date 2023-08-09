import Foundation
import UIKit
import AsyncDisplayKit
import AVFoundation
import Display
import SwiftSignalKit
import TelegramCore
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import StickerResources
import AccountContext
import MediaEditor
import UniversalMediaPlayer
import TelegramUniversalVideoContent

public final class DrawingStickerEntityView: DrawingEntityView {    
    private var stickerEntity: DrawingStickerEntity {
        return self.entity as! DrawingStickerEntity
    }
    
    var started: ((Double) -> Void)?
    
    public var updated: () -> Void = {}
    
    private var currentSize: CGSize?
    
    private let imageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    private var videoNode: UniversalVideoNode?
        
    private var didSetUpAnimationNode = false
    private let stickerFetchedDisposable = MetaDisposable()
    private let cachedDisposable = MetaDisposable()
    
    private var isVisible = true
    private var isPlaying = false
    
    init(context: AccountContext, entity: DrawingStickerEntity) {
        self.imageNode = TransformImageNode()
        
        super.init(context: context, entity: entity)
        
        self.addSubview(self.imageNode.view)
                
        self.setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.stickerFetchedDisposable.dispose()
        self.cachedDisposable.dispose()
    }
    
    private var file: TelegramMediaFile? {
        if case let .file(file) = self.stickerEntity.content {
            return file
        } else {
            return nil
        }
    }
    
    private var image: UIImage? {
        if case let .image(image, _) = self.stickerEntity.content {
            return image
        } else {
            return nil
        }
    }
    
    private var video: TelegramMediaFile? {
        if case let .video(file) = self.stickerEntity.content {
            return file
        } else {
            return nil
        }
    }
    
    private var dimensions: CGSize {
        switch self.stickerEntity.content {
        case let .file(file):
            return file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0)
        case let .image(image, _):
            return image.size
        case let .video(file):
            return file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0)
        case .dualVideoReference:
            return CGSize(width: 512.0, height: 512.0)
        }
    }
    
    private func setup() {
        if let file = self.file {
            if let dimensions = file.dimensions {
                if file.isAnimatedSticker || file.isVideoSticker || file.mimeType == "video/webm" {
                    if self.animationNode == nil {
                        let animationNode = DefaultAnimatedStickerNodeImpl()
                        animationNode.autoplay = false
                        self.animationNode = animationNode
                        animationNode.started = { [weak self, weak animationNode] in
                            self?.imageNode.isHidden = true
                                                        
                            if let animationNode = animationNode {
                                if animationNode.currentFrameCount == 1 {
                                    self?.stickerEntity.isExplicitlyStatic = true
                                }
                                let _ = (animationNode.status
                                |> take(1)
                                |> deliverOnMainQueue).start(next: { [weak self] status in
                                    self?.started?(status.duration)
                                })
                            }
                        }
                        self.addSubnode(animationNode)
                        
                        if file.isCustomTemplateEmoji {
                            animationNode.dynamicColor = UIColor(rgb: 0xffffff)
                        }
                    }
                    self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: self.context.account.postbox, userLocation: .other, file: file, small: false, size: dimensions.cgSize.aspectFitted(CGSize(width: 256.0, height: 256.0))))
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: self.context.account, userLocation: .other, fileReference: stickerPackFileReference(file), resource: file.resource).start())
                } else {
                    if let animationNode = self.animationNode {
                        animationNode.visibility = false
                        self.animationNode = nil
                        animationNode.removeFromSupernode()
                        self.imageNode.isHidden = false
                        self.didSetUpAnimationNode = false
                    }
                    self.imageNode.setSignal(chatMessageSticker(account: self.context.account, userLocation: .other, file: file, small: false, synchronousLoad: false))
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: self.context.account, userLocation: .other, fileReference: stickerPackFileReference(file), resource: chatMessageStickerResource(file: file, small: false)).start())
                }
                self.setNeedsLayout()
            }
        } else if let image = self.image {
            func drawImageWithOrientation(_ image: UIImage, size: CGSize, in context: CGContext) {
                let imageSize: CGSize
                
                switch image.imageOrientation {
                case .left, .leftMirrored, .right, .rightMirrored:
                    imageSize = CGSize(width: size.height, height: size.width)
                default:
                    imageSize = size
                }
                
                let imageRect = CGRect(origin: .zero, size: imageSize)
                                
                switch image.imageOrientation {
                case .down, .downMirrored:
                    context.translateBy(x: imageSize.width, y: imageSize.height)
                    context.rotate(by: CGFloat.pi)
                case .left, .leftMirrored:
                    context.translateBy(x: imageSize.width, y: 0)
                    context.rotate(by: CGFloat.pi / 2)
                case .right, .rightMirrored:
                    context.translateBy(x: 0, y: imageSize.height)
                    context.rotate(by: -CGFloat.pi / 2)
                default:
                    break
                }
                
                context.draw(image.cgImage!, in: imageRect)
            }
            
            var synchronous = false
            if case let .image(_, type) = self.stickerEntity.content {
                synchronous = type == .dualPhoto
            }
            self.imageNode.setSignal(.single({ arguments -> DrawingContext? in
                let context = DrawingContext(size: arguments.drawingSize, opaque: false, clear: true)
                context?.withFlippedContext({ ctx in
                    drawImageWithOrientation(image, size: arguments.drawingSize, in: ctx)
                })
                return context
            }), attemptSynchronously: synchronous)
            self.setNeedsLayout()
        } else if case let .video(file) = self.stickerEntity.content {
            let videoNode = UniversalVideoNode(
                postbox: self.context.account.postbox,
                audioSession: self.context.sharedContext.mediaManager.audioSession,
                manager: self.context.sharedContext.mediaManager.universalVideoManager,
                decoration: StickerVideoDecoration(),
                content: NativeVideoContent(
                    id: .contextResult(0, "\(UInt64.random(in: 0 ... UInt64.max))"),
                    userLocation: .other,
                    fileReference: .standalone(media: file),
                    imageReference: nil,
                    streamVideo: .story,
                    loopVideo: true,
                    enableSound: false,
                    soundMuted: true,
                    beginWithAmbientSound: false,
                    mixWithOthers: true,
                    useLargeThumbnail: false,
                    autoFetchFullSizeThumbnail: false,
                    tempFilePath: nil,
                    captureProtected: false,
                    hintDimensions: file.dimensions?.cgSize,
                    storeAfterDownload: nil,
                    displayImage: false,
                    hasSentFramesToDisplay: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.videoNode?.isHidden = false
                    }
                ),
                priority: .gallery
            )
            videoNode.canAttachContent = true
            videoNode.isUserInteractionEnabled = false
            videoNode.clipsToBounds = true
            self.addSubnode(videoNode)
            self.videoNode = videoNode
            self.setNeedsLayout()
            videoNode.play()
        }
    }
    
    public override func play() {
        self.isVisible = true
        self.applyVisibility()
        
        self.videoNode?.play()
    }
    
    public override func pause() {
        self.isVisible = false
        self.applyVisibility()
        
        self.videoNode?.pause()
    }
    
    public override func seek(to timestamp: Double) {
        self.isVisible = false
        self.isPlaying = false
        self.animationNode?.seekTo(.timestamp(timestamp))
        
        self.videoNode?.seek(timestamp)
    }
    
    override func resetToStart() {
        self.isVisible = false
        self.isPlaying = false
        self.animationNode?.seekTo(.timestamp(0.0))
    }
    
    override func updateVisibility(_ visibility: Bool) {
        self.isVisible = visibility
        self.applyVisibility()
    }
    
    private func applyVisibility() {
        let isPlaying = self.isVisible
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            
            if let file = self.file {
                if isPlaying && !self.didSetUpAnimationNode {
                    self.didSetUpAnimationNode = true
                    let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
                    let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 384.0, height: 384.0))
                    let source = AnimatedStickerResourceSource(account: self.context.account, resource: file.resource, isVideo: file.isVideoSticker || file.mimeType == "video/webm")
                    let pathPrefix = self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                    self.animationNode?.setup(source: source, width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), playbackMode: .loop, mode: .direct(cachePathPrefix: pathPrefix))
                    
                    self.cachedDisposable.set((source.cachedDataPath(width: 384, height: 384)
                    |> deliverOn(Queue.concurrentDefaultQueue())).start())
                }
            }
            self.animationNode?.visibility = isPlaying
        }
    }
    
    private var didApplyVisibility = false
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        
        if size.width > 0 && self.currentSize != size {
            self.currentSize = size
            
            let sideSize: CGFloat = max(size.width, size.height)
            let boundingSize = CGSize(width: sideSize, height: sideSize)
            
            let imageSize = self.dimensions.aspectFitted(boundingSize)
            let imageFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: (size.height - imageSize.height) / 2.0), size: imageSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
            self.imageNode.frame = imageFrame
            if let animationNode = self.animationNode {
                animationNode.frame = imageFrame
                animationNode.updateLayout(size: imageSize)
                
                if !self.didApplyVisibility {
                    self.didApplyVisibility = true
                    self.applyVisibility()
                }
            }
            
            if let videoNode = self.videoNode {
                let videoSize = self.dimensions.aspectFitted(boundingSize)
                videoNode.cornerRadius = floor(videoSize.width * 0.03)
                videoNode.frame = CGRect(origin: CGPoint(x: floor((size.width - videoSize.width) * 0.5), y: floor((size.height - videoSize.height) * 0.5)), size: videoSize)
                videoNode.updateLayout(size: videoSize, transition: .immediate)
            }
            
            self.update(animated: false)
        }
    }
        
    public override func update(animated: Bool) {
        self.center = self.stickerEntity.position
        
        let size = self.stickerEntity.baseSize
        
        self.bounds = CGRect(origin: .zero, size: self.dimensions.aspectFitted(size))
        self.transform = CGAffineTransformScale(CGAffineTransformMakeRotation(self.stickerEntity.rotation), self.stickerEntity.scale, self.stickerEntity.scale)
    
        let staticTransform = CATransform3DMakeScale(self.stickerEntity.mirrored ? -1.0 : 1.0, 1.0, 1.0)

        if animated {
            let isCurrentlyMirrored = ((self.imageNode.layer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0) < 0.0
            var animationSourceTransform = CATransform3DIdentity
            var animationTargetTransform = CATransform3DIdentity
            if isCurrentlyMirrored {
                animationSourceTransform = CATransform3DRotate(animationSourceTransform, .pi, 0.0, 1.0, 0.0)
                animationSourceTransform.m34 = -1.0 / self.imageNode.frame.width
            }
            if self.stickerEntity.mirrored {
                animationTargetTransform = CATransform3DRotate(animationTargetTransform, .pi, 0.0, 1.0, 0.0)
                animationTargetTransform.m34 = -1.0 / self.imageNode.frame.width
            }
            self.imageNode.transform = animationSourceTransform
            self.animationNode?.transform = animationSourceTransform
            UIView.animate(withDuration: 0.25, animations: {
                self.imageNode.transform = animationTargetTransform
                self.animationNode?.transform = animationTargetTransform
                self.videoNode?.transform = animationTargetTransform
            }, completion: { finished in
                self.imageNode.transform = staticTransform
                self.animationNode?.transform = staticTransform
                self.videoNode?.transform = staticTransform
            })
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.imageNode.transform = staticTransform
            self.animationNode?.transform = staticTransform
            self.videoNode?.transform = staticTransform
            CATransaction.commit()
        }
        
        self.updated()
    
        super.update(animated: animated)
    }
    
    override func updateSelectionView() {
        guard let selectionView = self.selectionView as? DrawingStickerEntititySelectionView else {
            return
        }
        self.pushIdentityTransformForMeasurement()
     
        selectionView.transform = .identity
        let maxSide = max(self.selectionBounds.width, self.selectionBounds.height)
        let center = self.selectionBounds.center
        
        let scale = self.superview?.superview?.layer.value(forKeyPath: "transform.scale.x") as? CGFloat ?? 1.0
        selectionView.center = self.convert(center, to: selectionView.superview)
        
        selectionView.bounds = CGRect(origin: .zero, size: CGSize(width: (maxSide * self.stickerEntity.scale) * scale + selectionView.selectionInset * 2.0, height: (maxSide * self.stickerEntity.scale) * scale + selectionView.selectionInset * 2.0))
        selectionView.transform = CGAffineTransformMakeRotation(self.stickerEntity.rotation)
        
        self.popIdentityTransformForMeasurement()
    }
        
    override func makeSelectionView() -> DrawingEntitySelectionView? {
        if let selectionView = self.selectionView {
            return selectionView
        }
        let selectionView = DrawingStickerEntititySelectionView()
        selectionView.entityView = self
        return selectionView
    }
}

final class DrawingStickerEntititySelectionView: DrawingEntitySelectionView {
    private let border = SimpleShapeLayer()
    private let leftHandle = SimpleShapeLayer()
    private let rightHandle = SimpleShapeLayer()
    
    override init(frame: CGRect) {
        let handleBounds = CGRect(origin: .zero, size: entitySelectionViewHandleSize)
        let handles = [
            self.leftHandle,
            self.rightHandle
        ]
        
        super.init(frame: frame)
        
        self.backgroundColor = .clear
        self.isOpaque = false
        
        self.border.lineCap = .round
        self.border.fillColor = UIColor.clear.cgColor
        self.border.strokeColor = UIColor(rgb: 0xffffff, alpha: 0.5).cgColor
        self.border.shadowColor = UIColor.black.cgColor
        self.border.shadowRadius = 1.0
        self.border.shadowOpacity = 0.5
        self.border.shadowOffset = CGSize()
        self.layer.addSublayer(self.border)
        
        for handle in handles {
            handle.bounds = handleBounds
            handle.fillColor = UIColor(rgb: 0x0a60ff).cgColor
            handle.strokeColor = UIColor(rgb: 0xffffff).cgColor
            handle.rasterizationScale = UIScreen.main.scale
            handle.shouldRasterize = true
            
            self.layer.addSublayer(handle)
        }
                
        self.snapTool.onSnapUpdated = { [weak self] type, snapped in
            if let self, let entityView = self.entityView {
                entityView.onSnapUpdated(type, snapped)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var scale: CGFloat = 1.0 {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    override var selectionInset: CGFloat {
        return 18.0
    }
    
    private let snapTool = DrawingEntitySnapTool()
    
    private var currentHandle: CALayer?
    override func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingStickerEntity else {
            return
        }
        let location = gestureRecognizer.location(in: self)
        
        switch gestureRecognizer.state {
        case .began:
            self.snapTool.maybeSkipFromStart(entityView: entityView, position: entity.position)
            
            if let sublayers = self.layer.sublayers {
                for layer in sublayers {
                    if layer.frame.contains(location) {
                        self.currentHandle = layer
                        self.snapTool.maybeSkipFromStart(entityView: entityView, rotation: entity.rotation)
                        entityView.onInteractionUpdated(true)
                        return
                    }
                }
            }
            self.currentHandle = self.layer
            entityView.onInteractionUpdated(true)
        case .changed:
            if self.currentHandle == nil {
                self.currentHandle = self.layer
            }

            let delta = gestureRecognizer.translation(in: entityView.superview)
            let parentLocation = gestureRecognizer.location(in: self.superview)
            let velocity = gestureRecognizer.velocity(in: entityView.superview)
                        
            var updatedPosition = entity.position
            var updatedScale = entity.scale
            var updatedRotation = entity.rotation
            
            if self.currentHandle === self.leftHandle || self.currentHandle === self.rightHandle {
                if gestureRecognizer.numberOfTouches > 1 {
                    return
                }
                var deltaX = gestureRecognizer.translation(in: self).x
                if self.currentHandle === self.leftHandle {
                    deltaX *= -1.0
                }
                let scaleDelta = (self.bounds.size.width + deltaX * 2.0) / self.bounds.size.width
                updatedScale *= scaleDelta
                
                let newAngle: CGFloat
                if self.currentHandle === self.leftHandle {
                    newAngle = atan2(self.center.y - parentLocation.y, self.center.x - parentLocation.x)
                } else {
                    newAngle = atan2(parentLocation.y - self.center.y, parentLocation.x - self.center.x)
                }
                var delta = newAngle - updatedRotation
                if delta < -.pi {
                    delta = 2.0 * .pi + delta
                }
                let velocityValue = sqrt(velocity.x * velocity.x + velocity.y * velocity.y) / 1000.0
                updatedRotation = self.snapTool.update(entityView: entityView, velocity: velocityValue, delta: delta, updatedRotation: newAngle, skipMultiplier: 1.0)
            } else if self.currentHandle === self.layer {
                updatedPosition.x += delta.x
                updatedPosition.y += delta.y
                
                updatedPosition = self.snapTool.update(entityView: entityView, velocity: velocity, delta: delta, updatedPosition: updatedPosition, size: entityView.frame.size)
            }
            
            entity.position = updatedPosition
            entity.scale = updatedScale
            entity.rotation = updatedRotation
            entityView.update()
            
            gestureRecognizer.setTranslation(.zero, in: entityView)
        case .ended, .cancelled:
            self.snapTool.reset()
            if self.currentHandle != nil {
                self.snapTool.rotationReset()
            }
            entityView.onInteractionUpdated(false)
        default:
            break
        }
        
        entityView.onPositionUpdated(entity.position)
    }
    
    override func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingStickerEntity else {
            return
        }
        
        if self.currentHandle != nil && self.currentHandle !== self.layer {
            return
        }

        switch gestureRecognizer.state {
        case .began, .changed:
            if case .began = gestureRecognizer.state {
                entityView.onInteractionUpdated(true)
            }
            let scale = gestureRecognizer.scale
            entity.scale = entity.scale * scale
            entityView.update()

            gestureRecognizer.scale = 1.0
        case .cancelled, .ended:
            entityView.onInteractionUpdated(false)
        default:
            break
        }
    }
    
    override func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingStickerEntity else {
            return
        }
        
        if self.currentHandle != nil && self.currentHandle !== self.layer {
            return
        }
        
        let velocity = gestureRecognizer.velocity
        var updatedRotation = entity.rotation
        var rotation: CGFloat = 0.0
        
        switch gestureRecognizer.state {
        case .began:
            self.snapTool.maybeSkipFromStart(entityView: entityView, rotation: entity.rotation)
            entityView.onInteractionUpdated(true)
        case .changed:
            rotation = gestureRecognizer.rotation
            updatedRotation += rotation
        
            updatedRotation = self.snapTool.update(entityView: entityView, velocity: velocity, delta: rotation, updatedRotation: updatedRotation)
            entity.rotation = updatedRotation
            entityView.update()
            
            gestureRecognizer.rotation = 0.0
        case .ended, .cancelled:
            self.snapTool.rotationReset()
            entityView.onInteractionUpdated(false)
        default:
            break
        }
                
        entityView.onPositionUpdated(entity.position)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.insetBy(dx: -22.0, dy: -22.0).contains(point)
    }
    
    override func layoutSubviews() {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingStickerEntity else {
            return
        }
        
        let inset = self.selectionInset - 10.0

        let bounds = CGRect(origin: .zero, size: CGSize(width: entitySelectionViewHandleSize.width / self.scale, height: entitySelectionViewHandleSize.height / self.scale))
        let handleSize = CGSize(width: 9.0 / self.scale, height: 9.0 / self.scale)
        let handlePath = CGPath(ellipseIn: CGRect(origin: CGPoint(x: (bounds.width - handleSize.width) / 2.0, y: (bounds.height - handleSize.height) / 2.0), size: handleSize), transform: nil)
        let lineWidth = (1.0 + UIScreenPixel) / self.scale
                
        let radius = (self.bounds.width - inset * 2.0) / 2.0
        let circumference: CGFloat = 2.0 * .pi * radius
        let relativeDashLength: CGFloat = 0.25
        
        self.border.lineWidth = 2.0 / self.scale
        
        let actualInset: CGFloat
        if entity.isRectangle {
            let aspectRatio = entity.baseSize.width / entity.baseSize.height
            
            let width: CGFloat
            let height: CGFloat
            
            if entity.baseSize.width > entity.baseSize.height {
                width = self.bounds.width - inset * 2.0
                height = self.bounds.height / aspectRatio - inset * 2.0
            } else {
                width = self.bounds.width * aspectRatio - inset * 2.0
                height = self.bounds.height - inset * 2.0
            }
            
            actualInset = floorToScreenPixels((self.bounds.width - width) / 2.0)
            
            let cornerRadius: CGFloat = 12.0 - self.scale
            let perimeter: CGFloat = 2.0 * (width + height - cornerRadius * (4.0 - .pi))
            let count = 12
            let dashLength = perimeter / CGFloat(count)
            self.border.lineDashPattern = [dashLength * relativeDashLength, dashLength * relativeDashLength] as [NSNumber]
            
            self.border.path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: floorToScreenPixels((self.bounds.width - width) / 2.0), y: floorToScreenPixels((self.bounds.height - height) / 2.0)), size: CGSize(width: width, height: height)), cornerRadius: cornerRadius).cgPath
        } else {
            actualInset = inset
            
            let count = 10
            let dashLength = circumference / CGFloat(count)
            self.border.lineDashPattern = [dashLength * relativeDashLength, dashLength * relativeDashLength] as [NSNumber]
            
            self.border.path = UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: inset, y: inset), size: CGSize(width: self.bounds.width - inset * 2.0, height: self.bounds.height - inset * 2.0))).cgPath
        }
        
        let handles = [
            self.leftHandle,
            self.rightHandle
        ]
        
        for handle in handles {
            handle.path = handlePath
            handle.bounds = bounds
            handle.lineWidth = lineWidth
        }
        
        
        self.leftHandle.position = CGPoint(x: actualInset, y: self.bounds.midY)
        self.rightHandle.position = CGPoint(x: self.bounds.maxX - actualInset, y: self.bounds.midY)
    }
}

private final class StickerVideoDecoration: UniversalVideoDecoration {
    public let backgroundNode: ASDisplayNode? = nil
    public let contentContainerNode: ASDisplayNode
    public let foregroundNode: ASDisplayNode? = nil
    
    private var contentNode: (ASDisplayNode & UniversalVideoContentNode)?
    
    private var validLayoutSize: CGSize?
    
    public init() {
        self.contentContainerNode = ASDisplayNode()
    }
    
    public func updateContentNode(_ contentNode: (UniversalVideoContentNode & ASDisplayNode)?) {
        if self.contentNode !== contentNode {
            let previous = self.contentNode
            self.contentNode = contentNode
            
            if let previous = previous {
                if previous.supernode === self.contentContainerNode {
                    previous.removeFromSupernode()
                }
            }
            
            if let contentNode = contentNode {
                if contentNode.supernode !== self.contentContainerNode {
                    self.contentContainerNode.addSubnode(contentNode)
                    if let validLayoutSize = self.validLayoutSize {
                        contentNode.frame = CGRect(origin: CGPoint(), size: validLayoutSize)
                        contentNode.updateLayout(size: validLayoutSize, transition: .immediate)
                    }
                }
            }
        }
    }
    
    public func updateCorners(_ corners: ImageCorners) {
        self.contentContainerNode.clipsToBounds = true
        if isRoundEqualCorners(corners) {
            self.contentContainerNode.cornerRadius = corners.topLeft.radius
        } else {
            let boundingSize: CGSize = CGSize(width: max(corners.topLeft.radius, corners.bottomLeft.radius) + max(corners.topRight.radius, corners.bottomRight.radius), height: max(corners.topLeft.radius, corners.topRight.radius) + max(corners.bottomLeft.radius, corners.bottomRight.radius))
            let size: CGSize = CGSize(width: boundingSize.width + corners.extendedEdges.left + corners.extendedEdges.right, height: boundingSize.height + corners.extendedEdges.top + corners.extendedEdges.bottom)
            let arguments = TransformImageArguments(corners: corners, imageSize: size, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets())
            guard let context = DrawingContext(size: size, clear: true) else {
                return
            }
            context.withContext { ctx in
                ctx.setFillColor(UIColor.black.cgColor)
                ctx.fill(arguments.drawingRect)
            }
            addCorners(context, arguments: arguments)
            
            if let maskImage = context.generateImage() {
                let mask = CALayer()
                mask.contents = maskImage.cgImage
                mask.contentsScale = maskImage.scale
                mask.contentsCenter = CGRect(x: max(corners.topLeft.radius, corners.bottomLeft.radius) / maskImage.size.width, y: max(corners.topLeft.radius, corners.topRight.radius) / maskImage.size.height, width: (maskImage.size.width - max(corners.topLeft.radius, corners.bottomLeft.radius) - max(corners.topRight.radius, corners.bottomRight.radius)) / maskImage.size.width, height: (maskImage.size.height - max(corners.topLeft.radius, corners.topRight.radius) - max(corners.bottomLeft.radius, corners.bottomRight.radius)) / maskImage.size.height)
                
                self.contentContainerNode.layer.mask = mask
                self.contentContainerNode.layer.mask?.frame = self.contentContainerNode.bounds
            }
        }
    }
    
    public func updateClippingFrame(_ frame: CGRect, completion: (() -> Void)?) {
        self.contentContainerNode.layer.animate(from: NSValue(cgRect: self.contentContainerNode.bounds), to: NSValue(cgRect: frame), keyPath: "bounds", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
        })

        if let maskLayer = self.contentContainerNode.layer.mask {
            maskLayer.animate(from: NSValue(cgRect: self.contentContainerNode.bounds), to: NSValue(cgRect: frame), keyPath: "bounds", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            })
            
            maskLayer.animate(from: NSValue(cgPoint: maskLayer.position), to: NSValue(cgPoint: frame.center), keyPath: "position", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            })
        }
        
        if let contentNode = self.contentNode {
            contentNode.layer.animate(from: NSValue(cgPoint: contentNode.layer.position), to: NSValue(cgPoint: frame.center), keyPath: "position", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
                completion?()
            })
        }
    }
    
    public func updateContentNodeSnapshot(_ snapshot: UIView?) {
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayoutSize = size
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        if let backgroundNode = self.backgroundNode {
            transition.updateFrame(node: backgroundNode, frame: bounds)
        }
        if let foregroundNode = self.foregroundNode {
            transition.updateFrame(node: foregroundNode, frame: bounds)
        }
        transition.updateFrame(node: self.contentContainerNode, frame: bounds)
        if let maskLayer = self.contentContainerNode.layer.mask {
            transition.updateFrame(layer: maskLayer, frame: bounds)
        }
        if let contentNode = self.contentNode {
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(), size: size))
            contentNode.updateLayout(size: size, transition: transition)
        }
    }
    
    public func setStatus(_ status: Signal<MediaPlayerStatus?, NoError>) {
    }
    
    public func tap() {
    }
}
