import Foundation
import UIKit
import AVFoundation
import Display
import SwiftSignalKit
import TelegramCore
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import StickerResources
import AccountContext
import MediaEditor

final class DrawingStickerEntityView: DrawingEntityView {
    private var stickerEntity: DrawingStickerEntity {
        return self.entity as! DrawingStickerEntity
    }
    
    var started: ((Double) -> Void)?
    
    private var currentSize: CGSize?
    
    private let imageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    
    private var videoPlayer: AVPlayer?
    private var videoLayer: AVPlayerLayer?
    private var videoImageView: UIImageView?
    
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
    
    private var video: String? {
        if case let .video(path, _) = self.stickerEntity.content {
            return path
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
        case let .video(_, image):
            if let image {
                let minSide = min(image.size.width, image.size.height)
                return CGSize(width: minSide, height: minSide)
            } else {
                return CGSize(width: 512.0, height: 512.0)
            }
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
        } else if case let .video(videoPath, image) = self.stickerEntity.content {
            let url = URL(fileURLWithPath: videoPath)
            let asset = AVURLAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)
            player.automaticallyWaitsToMinimizeStalling = false
            let layer = AVPlayerLayer(player: player)
            layer.masksToBounds = true
            layer.videoGravity = .resizeAspectFill
            
            self.layer.addSublayer(layer)
            
            self.videoPlayer = player
            self.videoLayer = layer
            
            let imageView = UIImageView(image: image)
            imageView.clipsToBounds = true
            imageView.contentMode = .scaleAspectFill
            self.addSubview(imageView)
            self.videoImageView = imageView
        }
    }
    
    override func play() {
        self.isVisible = true
        self.applyVisibility()
        
        if let player = self.videoPlayer {
            player.play()
            
            if let videoImageView = self.videoImageView {
                self.videoImageView = nil
                Queue.mainQueue().after(0.1) {
                    videoImageView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak videoImageView] _ in
                        videoImageView?.removeFromSuperview()
                    })
                }
            }
        }
    }
    
    override func pause() {
        self.isVisible = false
        self.applyVisibility()
        
        if let player = self.videoPlayer {
            player.pause()
        }
    }
    
    override func seek(to timestamp: Double) {
        self.isVisible = false
        self.isPlaying = false
        self.animationNode?.seekTo(.timestamp(timestamp))
        
        if let player = self.videoPlayer {
            player.seek(to: CMTime(seconds: timestamp, preferredTimescale: CMTimeScale(60.0)), toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: { _ in })
        }
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
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        
        if size.width > 0 && self.currentSize != size {
            self.currentSize = size
            
            let sideSize: CGFloat = size.width
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
            
            if let videoLayer = self.videoLayer {
                videoLayer.cornerRadius = imageFrame.width / 2.0
                videoLayer.frame = imageFrame
            }
            if let videoImageView = self.videoImageView {
                videoImageView.layer.cornerRadius = imageFrame.width / 2.0
                videoImageView.frame = imageFrame
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
                self.videoLayer?.transform = animationTargetTransform
            }, completion: { finished in
                self.imageNode.transform = staticTransform
                self.animationNode?.transform = staticTransform
                self.videoLayer?.transform = staticTransform
            })
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.imageNode.transform = staticTransform
            self.animationNode?.transform = staticTransform
            self.videoLayer?.transform = staticTransform
            CATransaction.commit()
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
        
    override func makeSelectionView() -> DrawingEntitySelectionView? {
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
                        entityView.onInteractionUpdated(true)
                        return
                    }
                }
            }
            self.currentHandle = self.layer
            entityView.onInteractionUpdated(true)
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
            
            gestureRecognizer.rotation = 0.0
        case .ended, .cancelled:
            self.snapTool.rotationReset()
            entityView.onInteractionUpdated(false)
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
    enum SnapType {
        case centerX
        case centerY
        case top
        case left
        case right
        case bottom
        case rotation(CGFloat?)
        
        static var allPositionTypes: [SnapType] {
            return [
                .centerX,
                .centerY,
                .top,
                .left,
                .right,
                .bottom
            ]
        }
    }
    
    struct SnapState {
        let skipped: CGFloat
        let waitForLeave: Bool
    }
    
    private var topEdgeState: SnapState?
    private var leftEdgeState: SnapState?
    private var rightEdgeState: SnapState?
    private var bottomEdgeState: SnapState?
    
    private var xState: SnapState?
    private var yState: SnapState?
    
    private var rotationState: (angle: CGFloat, skipped: CGFloat, waitForLeave: Bool)?
    
    var onSnapUpdated: (SnapType, Bool) -> Void = { _, _ in }
    
    var previousTopEdgeSnapTimestamp: Double?
    var previousLeftEdgeSnapTimestamp: Double?
    var previousRightEdgeSnapTimestamp: Double?
    var previousBottomEdgeSnapTimestamp: Double?
    
    var previousXSnapTimestamp: Double?
    var previousYSnapTimestamp: Double?
    var previousRotationSnapTimestamp: Double?
    
    func reset() {
        self.topEdgeState = nil
        self.leftEdgeState = nil
        self.rightEdgeState = nil
        self.bottomEdgeState = nil
        self.xState = nil
        self.yState = nil
    
        for type in SnapType.allPositionTypes {
            self.onSnapUpdated(type, false)
        }
    }
    
    func rotationReset() {
        self.rotationState = nil
        self.onSnapUpdated(.rotation(nil), false)
    }
    
    func maybeSkipFromStart(entityView: DrawingEntityView, position: CGPoint) {
        self.topEdgeState = nil
        self.leftEdgeState = nil
        self.rightEdgeState = nil
        self.bottomEdgeState = nil
        
        self.xState = nil
        self.yState = nil
        
        let snapXDelta: CGFloat = (entityView.superview?.frame.width ?? 0.0) * 0.02
        let snapYDelta: CGFloat = (entityView.superview?.frame.width ?? 0.0) * 0.02
        
        if let snapLocation = (entityView.superview as? DrawingEntitiesView)?.getEntityCenterPosition() {
            if position.x > snapLocation.x - snapXDelta && position.x < snapLocation.x + snapXDelta {
                self.xState = SnapState(skipped: 0.0, waitForLeave: true)
            }
            
            if position.y > snapLocation.y - snapYDelta && position.y < snapLocation.y + snapYDelta {
                self.yState = SnapState(skipped: 0.0, waitForLeave: true)
            }
        }
    }
        
    func update(entityView: DrawingEntityView, velocity: CGPoint, delta: CGPoint, updatedPosition: CGPoint, size: CGSize) -> CGPoint {
        var updatedPosition = updatedPosition
        
        guard let snapCenterLocation = (entityView.superview as? DrawingEntitiesView)?.getEntityCenterPosition() else {
            return updatedPosition
        }
        let snapEdgeLocations = (entityView.superview as? DrawingEntitiesView)?.getEntityEdgePositions()
        
        let currentTimestamp = CACurrentMediaTime()
        
        let snapDelta: CGFloat = (entityView.superview?.frame.width ?? 0.0) * 0.02
        let snapVelocity: CGFloat = snapDelta * 12.0
        let snapSkipTranslation: CGFloat = snapDelta * 2.0
        
        let topPoint = updatedPosition.y - size.height / 2.0
        let leftPoint = updatedPosition.x - size.width / 2.0
        let rightPoint = updatedPosition.x + size.width / 2.0
        let bottomPoint = updatedPosition.y + size.height / 2.0
        
        func process(
            state: SnapState?,
            velocity: CGFloat,
            delta: CGFloat,
            value: CGFloat,
            snapVelocity: CGFloat,
            snapToValue: CGFloat?,
            snapDelta: CGFloat,
            snapSkipTranslation: CGFloat,
            previousSnapTimestamp: Double?,
            onSnapUpdated: (Bool) -> Void
        ) -> (
            value: CGFloat,
            state: SnapState?,
            snapTimestamp: Double?
        ) {
            var updatedValue = value
            var updatedState = state
            var updatedPreviousSnapTimestamp = previousSnapTimestamp
            if abs(velocity) < snapVelocity || state?.waitForLeave == true {
                if let snapToValue {
                    if let state {
                        let skipped = state.skipped
                        let waitForLeave = state.waitForLeave
                        if waitForLeave {
                            if value > snapToValue - snapDelta * 2.0 && value < snapToValue + snapDelta * 2.0  {
                                
                            } else {
                                updatedState = nil
                            }
                        } else if abs(skipped) < snapSkipTranslation {
                            updatedState = SnapState(skipped: skipped + delta, waitForLeave: false)
                            updatedValue = snapToValue
                        } else {
                            updatedState = SnapState(skipped: snapSkipTranslation, waitForLeave: true)
                            onSnapUpdated(false)
                        }
                    } else {
                        if value > snapToValue - snapDelta && value < snapToValue + snapDelta {
                            if let previousSnapTimestamp, currentTimestamp - previousSnapTimestamp < snapTimeout {
                                
                            } else {
                                updatedPreviousSnapTimestamp = currentTimestamp
                                updatedState = SnapState(skipped: 0.0, waitForLeave: false)
                                updatedValue = snapToValue
                                onSnapUpdated(true)
                            }
                        }
                    }
                }
            } else {
                updatedState = nil
                onSnapUpdated(false)
            }
            return (updatedValue, updatedState, updatedPreviousSnapTimestamp)
        }
        
        let (updatedXValue, updatedXState, updatedXPreviousTimestamp) = process(
            state: self.xState,
            velocity: velocity.x,
            delta: delta.x,
            value: updatedPosition.x,
            snapVelocity: snapVelocity,
            snapToValue: snapCenterLocation.x,
            snapDelta: snapDelta,
            snapSkipTranslation: snapSkipTranslation,
            previousSnapTimestamp: self.previousXSnapTimestamp,
            onSnapUpdated: { [weak self] snapped in
                self?.onSnapUpdated(.centerX, snapped)
            }
        )
        self.xState = updatedXState
        self.previousXSnapTimestamp = updatedXPreviousTimestamp
        
        let (updatedYValue, updatedYState, updatedYPreviousTimestamp) = process(
            state: self.yState,
            velocity: velocity.y,
            delta: delta.y,
            value: updatedPosition.y,
            snapVelocity: snapVelocity,
            snapToValue: snapCenterLocation.y,
            snapDelta: snapDelta,
            snapSkipTranslation: snapSkipTranslation,
            previousSnapTimestamp: self.previousYSnapTimestamp,
            onSnapUpdated: { [weak self] snapped in
                self?.onSnapUpdated(.centerY, snapped)
            }
        )
        self.yState = updatedYState
        self.previousYSnapTimestamp = updatedYPreviousTimestamp
        
        if let snapEdgeLocations {
            if updatedXState == nil {
                let (updatedXLeftEdgeValue, updatedLeftEdgeState, updatedLeftEdgePreviousTimestamp) = process(
                    state: self.leftEdgeState,
                    velocity: velocity.x,
                    delta: delta.x,
                    value: leftPoint,
                    snapVelocity: snapVelocity,
                    snapToValue: snapEdgeLocations.left,
                    snapDelta: snapDelta,
                    snapSkipTranslation: snapSkipTranslation,
                    previousSnapTimestamp: self.previousLeftEdgeSnapTimestamp,
                    onSnapUpdated: { [weak self] snapped in
                        self?.onSnapUpdated(.left, snapped)
                    }
                )
                self.leftEdgeState = updatedLeftEdgeState
                self.previousLeftEdgeSnapTimestamp = updatedLeftEdgePreviousTimestamp
                
                if updatedLeftEdgeState != nil {
                    updatedPosition.x = updatedXLeftEdgeValue + size.width / 2.0
                    
                    self.rightEdgeState = nil
                    self.previousRightEdgeSnapTimestamp = nil
                } else {
                    let (updatedXRightEdgeValue, updatedRightEdgeState, updatedRightEdgePreviousTimestamp) = process(
                        state: self.rightEdgeState,
                        velocity: velocity.x,
                        delta: delta.x,
                        value: rightPoint,
                        snapVelocity: snapVelocity,
                        snapToValue: snapEdgeLocations.right,
                        snapDelta: snapDelta,
                        snapSkipTranslation: snapSkipTranslation,
                        previousSnapTimestamp: self.previousRightEdgeSnapTimestamp,
                        onSnapUpdated: { [weak self] snapped in
                            self?.onSnapUpdated(.right, snapped)
                        }
                    )
                    self.rightEdgeState = updatedRightEdgeState
                    self.previousRightEdgeSnapTimestamp = updatedRightEdgePreviousTimestamp
                    
                    updatedPosition.x = updatedXRightEdgeValue - size.width / 2.0
                }
            } else {
                updatedPosition.x = updatedXValue
            }
            
            if updatedYState == nil {
                let (updatedYTopEdgeValue, updatedTopEdgeState, updatedTopEdgePreviousTimestamp) = process(
                    state: self.topEdgeState,
                    velocity: velocity.y,
                    delta: delta.y,
                    value: topPoint,
                    snapVelocity: snapVelocity,
                    snapToValue: snapEdgeLocations.top,
                    snapDelta: snapDelta,
                    snapSkipTranslation: snapSkipTranslation,
                    previousSnapTimestamp: self.previousTopEdgeSnapTimestamp,
                    onSnapUpdated: { [weak self] snapped in
                        self?.onSnapUpdated(.top, snapped)
                    }
                )
                self.topEdgeState = updatedTopEdgeState
                self.previousTopEdgeSnapTimestamp = updatedTopEdgePreviousTimestamp
                
                if updatedTopEdgeState != nil {
                    updatedPosition.y = updatedYTopEdgeValue + size.height / 2.0
                    
                    self.bottomEdgeState = nil
                    self.previousBottomEdgeSnapTimestamp = nil
                } else {
                    let (updatedYBottomEdgeValue, updatedBottomEdgeState, updatedBottomEdgePreviousTimestamp) = process(
                        state: self.bottomEdgeState,
                        velocity: velocity.y,
                        delta: delta.y,
                        value: bottomPoint,
                        snapVelocity: snapVelocity,
                        snapToValue: snapEdgeLocations.bottom,
                        snapDelta: snapDelta,
                        snapSkipTranslation: snapSkipTranslation,
                        previousSnapTimestamp: self.previousBottomEdgeSnapTimestamp,
                        onSnapUpdated: { [weak self] snapped in
                            self?.onSnapUpdated(.bottom, snapped)
                        }
                    )
                    self.bottomEdgeState = updatedBottomEdgeState
                    self.previousBottomEdgeSnapTimestamp = updatedBottomEdgePreviousTimestamp
                    
                    updatedPosition.y = updatedYBottomEdgeValue - size.height / 2.0
                }
            } else {
                updatedPosition.y = updatedYValue
            }
        } else {
            updatedPosition.x = updatedXValue
            updatedPosition.y = updatedYValue
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
        
        let snapDelta: CGFloat = 0.02
        let snapVelocity: CGFloat = snapDelta * 8.0
        let snapSkipRotation: CGFloat = snapDelta * 5.0
        
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
                    self.onSnapUpdated(.rotation(nil), false)
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
                            self.onSnapUpdated(.rotation(snapRotation), true)
                        }
                        break
                    }
                }
            }
        } else {
            self.rotationState = nil
            self.onSnapUpdated(.rotation(nil), false)
        }
        
        return updatedRotation
    }
}
