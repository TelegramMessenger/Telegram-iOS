import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import StickerResources
import AccountContext

public final class DrawingStickerEntity: DrawingEntity, Codable {
    public enum Content {
        case file(TelegramMediaFile)
        case image(UIImage)
    }
    private enum CodingKeys: String, CodingKey {
        case uuid
        case file
        case image
        case referenceDrawingSize
        case position
        case scale
        case rotation
        case mirrored
    }
    
    public let uuid: UUID
    public let content: Content
    
    public var referenceDrawingSize: CGSize
    public var position: CGPoint
    public var scale: CGFloat
    public var rotation: CGFloat
    public var mirrored: Bool
    
    public var color: DrawingColor = DrawingColor.clear
    public var lineWidth: CGFloat = 0.0
    
    public var center: CGPoint {
        return self.position
    }
    
    public var baseSize: CGSize {
        let size = max(10.0, min(self.referenceDrawingSize.width, self.referenceDrawingSize.height) * 0.2)
        return CGSize(width: size, height: size)
    }
    
    public var isAnimated: Bool {
        switch self.content {
        case let .file(file):
            return file.isAnimatedSticker || file.isVideoSticker || file.mimeType == "video/webm"
        case .image:
            return false
        }
    }
    
    public init(content: Content) {
        self.uuid = UUID()
        self.content = content
        
        self.referenceDrawingSize = .zero
        self.position = CGPoint()
        self.scale = 1.0
        self.rotation = 0.0
        self.mirrored = false
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(UUID.self, forKey: .uuid)
        if let file = try container.decodeIfPresent(TelegramMediaFile.self, forKey: .file) {
            self.content = .file(file)
        } else if let imageData = try container.decodeIfPresent(Data.self, forKey: .image), let image = UIImage(data: imageData) {
            self.content = .image(image)
        } else {
            fatalError()
        }
        self.referenceDrawingSize = try container.decode(CGSize.self, forKey: .referenceDrawingSize)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.scale = try container.decode(CGFloat.self, forKey: .scale)
        self.rotation = try container.decode(CGFloat.self, forKey: .rotation)
        self.mirrored = try container.decode(Bool.self, forKey: .mirrored)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.uuid, forKey: .uuid)
        switch self.content {
        case let .file(file):
            try container.encode(file, forKey: .file)
        case let .image(image):
            try container.encodeIfPresent(image.pngData(), forKey: .image)
        }
        try container.encode(self.referenceDrawingSize, forKey: .referenceDrawingSize)
        try container.encode(self.position, forKey: .position)
        try container.encode(self.scale, forKey: .scale)
        try container.encode(self.rotation, forKey: .rotation)
        try container.encode(self.mirrored, forKey: .mirrored)
    }
        
    public func duplicate() -> DrawingEntity {
        let newEntity = DrawingStickerEntity(content: self.content)
        newEntity.referenceDrawingSize = self.referenceDrawingSize
        newEntity.position = self.position
        newEntity.scale = self.scale
        newEntity.rotation = self.rotation
        newEntity.mirrored = self.mirrored
        return newEntity
    }
    
    public weak var currentEntityView: DrawingEntityView?
    public func makeView(context: AccountContext) -> DrawingEntityView {
        let entityView = DrawingStickerEntityView(context: context, entity: self)
        self.currentEntityView = entityView
        return entityView
    }
    
    public func prepareForRender() {
    }
}

final class DrawingStickerEntityView: DrawingEntityView {
    private var stickerEntity: DrawingStickerEntity {
        return self.entity as! DrawingStickerEntity
    }
    
    var started: ((Double) -> Void)?
    
    private var currentSize: CGSize?
    
    private let imageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    
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
        if case let .image(image) = self.stickerEntity.content {
            return image
        } else {
            return nil
        }
    }
    
    private var dimensions: CGSize {
        switch self.stickerEntity.content {
            case let .file(file):
                return file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0)
            case let .image(image):
                return image.size
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
                                let _ = (animationNode.status
                                |> take(1)
                                |> deliverOnMainQueue).start(next: { [weak self] status in
                                    self?.started?(status.duration)
                                })
                            }
                        }
                        self.addSubnode(animationNode)
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
            self.imageNode.setSignal(.single({ arguments -> DrawingContext? in
                let context = DrawingContext(size: arguments.drawingSize, opaque: false, clear: true)
                context?.withFlippedContext({ ctx in
                    if let cgImage = image.cgImage {
                        ctx.draw(cgImage, in: CGRect(origin: .zero, size: arguments.drawingSize))
                    }
                })
                return context
            }))
            self.setNeedsLayout()
        }
    }
    
    override func play() {
        self.isVisible = true
        self.applyVisibility()
    }
    
    override func pause() {
        self.isVisible = false
        self.applyVisibility()
    }
    
    override func seek(to timestamp: Double) {
        self.isVisible = false
        self.isPlaying = false
        self.animationNode?.seekTo(.timestamp(timestamp))
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
                    self.animationNode?.setup(source: source, width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
                    
                    self.cachedDisposable.set((source.cachedDataPath(width: 384, height: 384)
                    |> deliverOn(Queue.concurrentDefaultQueue())).start())
                }
            }
            self.animationNode?.visibility = isPlaying
        }
    }
    
    private var didApplyVisibility = false
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        
        if size.width > 0 && self.currentSize != size {
            self.currentSize = size
            
            let sideSize: CGFloat = size.width
            let boundingSize = CGSize(width: sideSize, height: sideSize)
            
            let imageSize = self.dimensions.aspectFitted(boundingSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
            self.imageNode.frame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: (size.height - imageSize.height) / 2.0), size: imageSize)
            if let animationNode = self.animationNode {
                animationNode.frame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: (size.height - imageSize.height) / 2.0), size: imageSize)
                animationNode.updateLayout(size: imageSize)
                
                if !self.didApplyVisibility {
                    self.didApplyVisibility = true
                    self.applyVisibility()
                }
            }
            self.update(animated: false)
        }
    }
        
    override func update(animated: Bool) {
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
            }, completion: { finished in
                self.imageNode.transform = staticTransform
                self.animationNode?.transform = staticTransform
            })
        } else {
            self.imageNode.transform = staticTransform
            self.animationNode?.transform = staticTransform
        }
    
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
        
    override func makeSelectionView() -> DrawingEntitySelectionView {
        if let selectionView = self.selectionView {
            return selectionView
        }
        let selectionView = DrawingStickerEntititySelectionView()
        selectionView.entityView = self
        return selectionView
    }
}

final class DrawingStickerEntititySelectionView: DrawingEntitySelectionView, UIGestureRecognizerDelegate {
    private let border = SimpleShapeLayer()
    private let leftHandle = SimpleShapeLayer()
    private let rightHandle = SimpleShapeLayer()
    
    private var panGestureRecognizer: UIPanGestureRecognizer!
    
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
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        panGestureRecognizer.delegate = self
        self.addGestureRecognizer(panGestureRecognizer)
        self.panGestureRecognizer = panGestureRecognizer
        
        self.snapTool.onSnapXUpdated = { [weak self] snapped in
            if let strongSelf = self, let entityView = strongSelf.entityView {
                entityView.onSnapToXAxis(snapped)
            }
        }
        
        self.snapTool.onSnapYUpdated = { [weak self] snapped in
            if let strongSelf = self, let entityView = strongSelf.entityView {
                entityView.onSnapToYAxis(snapped)
            }
        }
        
        self.snapTool.onSnapRotationUpdated = { [weak self] snappedAngle in
            if let strongSelf = self, let entityView = strongSelf.entityView {
                entityView.onSnapToAngle(snappedAngle)
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
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    private let snapTool = DrawingEntitySnapTool()
    
    private var currentHandle: CALayer?
    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
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
                        return
                    }
                }
            }
            self.currentHandle = self.layer
        case .changed:
            let delta = gestureRecognizer.translation(in: entityView.superview)
            let parentLocation = gestureRecognizer.location(in: self.superview)
            let velocity = gestureRecognizer.velocity(in: entityView.superview)
                        
            var updatedPosition = entity.position
            var updatedScale = entity.scale
            var updatedRotation = entity.rotation
            if self.currentHandle === self.leftHandle || self.currentHandle === self.rightHandle {
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
                
             //   let delta = newAngle - updatedRotation
                updatedRotation = newAngle// self.snapTool.update(entityView: entityView, velocity: 0.0, delta: delta, updatedRotation: newAngle)
            } else if self.currentHandle === self.layer {
                updatedPosition.x += delta.x
                updatedPosition.y += delta.y
                
                updatedPosition = self.snapTool.update(entityView: entityView, velocity: velocity, delta: delta, updatedPosition: updatedPosition)
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
        default:
            break
        }
        
        entityView.onPositionUpdated(entity.position)
    }
    
    override func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingStickerEntity else {
            return
        }

        switch gestureRecognizer.state {
        case .began, .changed:
            let scale = gestureRecognizer.scale
            entity.scale = entity.scale * scale
            entityView.update()

            gestureRecognizer.scale = 1.0
        default:
            break
        }
    }
    
    override func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingStickerEntity else {
            return
        }
        
        let velocity = gestureRecognizer.velocity
        var updatedRotation = entity.rotation
        var rotation: CGFloat = 0.0
        
        switch gestureRecognizer.state {
        case .began:
            self.snapTool.maybeSkipFromStart(entityView: entityView, rotation: entity.rotation)
        case .changed:
            rotation = gestureRecognizer.rotation
            updatedRotation += rotation
            
            gestureRecognizer.rotation = 0.0
        case .ended, .cancelled:
            self.snapTool.rotationReset()
        default:
            break
        }
        
        updatedRotation = self.snapTool.update(entityView: entityView, velocity: velocity, delta: rotation, updatedRotation: updatedRotation)
        entity.rotation = updatedRotation
        entityView.update()
        
        entityView.onPositionUpdated(entity.position)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.insetBy(dx: -22.0, dy: -22.0).contains(point)
    }
    
    override func layoutSubviews() {
        let inset = self.selectionInset - 10.0

        let bounds = CGRect(origin: .zero, size: CGSize(width: entitySelectionViewHandleSize.width / self.scale, height: entitySelectionViewHandleSize.height / self.scale))
        let handleSize = CGSize(width: 9.0 / self.scale, height: 9.0 / self.scale)
        let handlePath = CGPath(ellipseIn: CGRect(origin: CGPoint(x: (bounds.width - handleSize.width) / 2.0, y: (bounds.height - handleSize.height) / 2.0), size: handleSize), transform: nil)
        let lineWidth = (1.0 + UIScreenPixel) / self.scale

        let handles = [
            self.leftHandle,
            self.rightHandle
        ]
        
        for handle in handles {
            handle.path = handlePath
            handle.bounds = bounds
            handle.lineWidth = lineWidth
        }
        
        self.leftHandle.position = CGPoint(x: inset, y: self.bounds.midY)
        self.rightHandle.position = CGPoint(x: self.bounds.maxX - inset, y: self.bounds.midY)
        

        let radius = (self.bounds.width - inset * 2.0) / 2.0
        let circumference: CGFloat = 2.0 * .pi * radius
        let count = 10
        let relativeDashLength: CGFloat = 0.25
        let dashLength = circumference / CGFloat(count)
        self.border.lineDashPattern = [dashLength * relativeDashLength, dashLength * relativeDashLength] as [NSNumber]
        
        self.border.lineWidth = 2.0 / self.scale
        self.border.path = UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: inset, y: inset), size: CGSize(width: self.bounds.width - inset * 2.0, height: self.bounds.height - inset * 2.0))).cgPath
    }
}

private let snapTimeout = 1.0

class DrawingEntitySnapTool {
    private var xState: (skipped: CGFloat, waitForLeave: Bool)?
    private var yState: (skipped: CGFloat, waitForLeave: Bool)?
    private var rotationState: (angle: CGFloat, skipped: CGFloat, waitForLeave: Bool)?
    
    var onSnapXUpdated: (Bool) -> Void = { _ in }
    var onSnapYUpdated: (Bool) -> Void = { _ in }
    var onSnapRotationUpdated: (CGFloat?) -> Void = { _ in }
    
    var previousXSnapTimestamp: Double?
    var previousYSnapTimestamp: Double?
    var previousRotationSnapTimestamp: Double?
    
    func reset() {
        self.xState = nil
        self.yState = nil
    
        self.onSnapXUpdated(false)
        self.onSnapYUpdated(false)
    }
    
    func rotationReset() {
        self.rotationState = nil
        self.onSnapRotationUpdated(nil)
    }
    
    func maybeSkipFromStart(entityView: DrawingEntityView, position: CGPoint) {
        self.xState = nil
        self.yState = nil
        
        let snapXDelta: CGFloat = (entityView.superview?.frame.width ?? 0.0) * 0.02
        let snapYDelta: CGFloat = (entityView.superview?.frame.width ?? 0.0) * 0.02
        
        if let snapLocation = (entityView.superview as? DrawingEntitiesView)?.getEntityCenterPosition() {
            if position.x > snapLocation.x - snapXDelta && position.x < snapLocation.x + snapXDelta {
                self.xState = (0.0, true)
            }
            
            if position.y > snapLocation.y - snapYDelta && position.y < snapLocation.y + snapYDelta {
                self.yState = (0.0, true)
            }
        }
    }
        
    func update(entityView: DrawingEntityView, velocity: CGPoint, delta: CGPoint, updatedPosition: CGPoint) -> CGPoint {
        var updatedPosition = updatedPosition
        
        let currentTimestamp = CACurrentMediaTime()
        
        let snapXDelta: CGFloat = (entityView.superview?.frame.width ?? 0.0) * 0.02
        let snapXVelocity: CGFloat = snapXDelta * 12.0
        let snapXSkipTranslation: CGFloat = snapXDelta * 2.0
        
        if abs(velocity.x) < snapXVelocity || self.xState?.waitForLeave == true {
            if let snapLocation = (entityView.superview as? DrawingEntitiesView)?.getEntityCenterPosition() {
                if let (skipped, waitForLeave) = self.xState {
                    if waitForLeave {
                        if updatedPosition.x > snapLocation.x - snapXDelta * 2.0 && updatedPosition.x < snapLocation.x + snapXDelta * 2.0  {
                            
                        } else {
                            self.xState = nil
                        }
                    } else if abs(skipped) < snapXSkipTranslation {
                        self.xState = (skipped + delta.x, false)
                        updatedPosition.x = snapLocation.x
                    } else {
                        self.xState = (snapXSkipTranslation, true)
                        self.onSnapXUpdated(false)
                    }
                } else {
                    if updatedPosition.x > snapLocation.x - snapXDelta && updatedPosition.x < snapLocation.x + snapXDelta {
                        if let previousXSnapTimestamp, currentTimestamp - previousXSnapTimestamp < snapTimeout {
                            
                        } else {
                            self.previousXSnapTimestamp = currentTimestamp
                            self.xState = (0.0, false)
                            updatedPosition.x = snapLocation.x
                            self.onSnapXUpdated(true)
                        }
                    }
                }
            }
        } else {
            self.xState = nil
            self.onSnapXUpdated(false)
        }
        
        let snapYDelta: CGFloat = (entityView.superview?.frame.width ?? 0.0) * 0.02
        let snapYVelocity: CGFloat = snapYDelta * 12.0
        let snapYSkipTranslation: CGFloat = snapYDelta * 2.0
        
        if abs(velocity.y) < snapYVelocity || self.yState?.waitForLeave == true {
            if let snapLocation = (entityView.superview as? DrawingEntitiesView)?.getEntityCenterPosition() {
                if let (skipped, waitForLeave) = self.yState {
                    if waitForLeave {
                        if updatedPosition.y > snapLocation.y - snapYDelta * 2.0 && updatedPosition.y < snapLocation.y + snapYDelta * 2.0 {
                            
                        } else {
                            self.yState = nil
                        }
                    } else if abs(skipped) < snapYSkipTranslation {
                        self.yState = (skipped + delta.y, false)
                        updatedPosition.y = snapLocation.y
                    } else {
                        self.yState = (snapYSkipTranslation, true)
                        self.onSnapYUpdated(false)
                    }
                } else {
                    if updatedPosition.y > snapLocation.y - snapYDelta && updatedPosition.y < snapLocation.y + snapYDelta {
                        if let previousYSnapTimestamp, currentTimestamp - previousYSnapTimestamp < snapTimeout {
                            
                        } else {
                            self.previousYSnapTimestamp = currentTimestamp
                            self.yState = (0.0, false)
                            updatedPosition.y = snapLocation.y
                            self.onSnapYUpdated(true)
                        }
                    }
                }
            }
        } else {
            self.yState = nil
            self.onSnapYUpdated(false)
        }
        
        return updatedPosition
    }
    
    private let snapRotations: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    func maybeSkipFromStart(entityView: DrawingEntityView, rotation: CGFloat) {
        self.rotationState = nil
        
        let snapDelta: CGFloat = 0.25
        for snapRotation in self.snapRotations {
            let snapRotation = snapRotation * .pi
            if rotation > snapRotation - snapDelta && rotation < snapRotation + snapDelta {
                self.rotationState = (snapRotation, 0.0, true)
                break
            }
        }
    }
    
    func update(entityView: DrawingEntityView, velocity: CGFloat, delta: CGFloat, updatedRotation: CGFloat) -> CGFloat {
        var updatedRotation = updatedRotation
        if updatedRotation < 0.0 {
            updatedRotation = 2.0 * .pi + updatedRotation
        } else if updatedRotation > 2.0 * .pi {
            while updatedRotation > 2.0 * .pi {
                updatedRotation -= 2.0 * .pi
            }
        }
        
        let currentTimestamp = CACurrentMediaTime()
        
        let snapDelta: CGFloat = 0.1
        let snapVelocity: CGFloat = snapDelta * 5.0
        let snapSkipRotation: CGFloat = snapDelta * 2.0
        
        if abs(velocity) < snapVelocity || self.rotationState?.waitForLeave == true {
            if let (snapRotation, skipped, waitForLeave) = self.rotationState {
                if waitForLeave {
                    if updatedRotation > snapRotation - snapDelta * 2.0 && updatedRotation < snapRotation + snapDelta {
                        
                    } else {
                        self.rotationState = nil
                    }
                } else if abs(skipped) < snapSkipRotation {
                    self.rotationState = (snapRotation, skipped + delta, false)
                    updatedRotation = snapRotation
                } else {
                    self.rotationState = (snapRotation, snapSkipRotation, true)
                    self.onSnapRotationUpdated(nil)
                }
            } else {
                for snapRotation in self.snapRotations {
                    let snapRotation = snapRotation * .pi
                    if updatedRotation > snapRotation - snapDelta && updatedRotation < snapRotation + snapDelta {
                        if let previousRotationSnapTimestamp, currentTimestamp - previousRotationSnapTimestamp < snapTimeout {
                            
                        } else {
                            self.previousRotationSnapTimestamp = currentTimestamp
                            self.rotationState = (snapRotation, 0.0, false)
                            updatedRotation = snapRotation
                            self.onSnapRotationUpdated(snapRotation)
                        }
                        break
                    }
                }
            }
        } else {
            self.rotationState = nil
            self.onSnapRotationUpdated(nil)
        }
        
        return updatedRotation
    }
}
