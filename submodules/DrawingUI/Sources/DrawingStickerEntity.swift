import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import StickerResources
import AccountContext

final class DrawingStickerEntity: DrawingEntity, Codable {
    private enum CodingKeys: String, CodingKey {
        case uuid
        case isAnimated
        case file
        case referenceDrawingSize
        case position
        case scale
        case rotation
        case mirrored
    }
    
    let uuid: UUID
    let isAnimated: Bool
    let file: TelegramMediaFile
    
    var referenceDrawingSize: CGSize
    var position: CGPoint
    var scale: CGFloat
    var rotation: CGFloat
    var mirrored: Bool
    
    var color: DrawingColor = DrawingColor.clear
    var lineWidth: CGFloat = 0.0
    
    var center: CGPoint {
        return self.position
    }
    
    init(file: TelegramMediaFile) {
        self.uuid = UUID()
        self.isAnimated = file.isAnimatedSticker
        
        self.file = file
        
        self.referenceDrawingSize = .zero
        self.position = CGPoint()
        self.scale = 1.0
        self.rotation = 0.0
        self.mirrored = false
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(UUID.self, forKey: .uuid)
        self.isAnimated = try container.decode(Bool.self, forKey: .isAnimated)
        self.file = try container.decode(TelegramMediaFile.self, forKey: .file)
        self.referenceDrawingSize = try container.decode(CGSize.self, forKey: .referenceDrawingSize)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.scale = try container.decode(CGFloat.self, forKey: .scale)
        self.rotation = try container.decode(CGFloat.self, forKey: .rotation)
        self.mirrored = try container.decode(Bool.self, forKey: .mirrored)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.uuid, forKey: .uuid)
        try container.encode(self.isAnimated, forKey: .isAnimated)
        try container.encode(self.file, forKey: .file)
        try container.encode(self.referenceDrawingSize, forKey: .referenceDrawingSize)
        try container.encode(self.position, forKey: .position)
        try container.encode(self.scale, forKey: .scale)
        try container.encode(self.rotation, forKey: .rotation)
        try container.encode(self.mirrored, forKey: .mirrored)
    }
        
    func duplicate() -> DrawingEntity {
        let newEntity = DrawingStickerEntity(file: self.file)
        newEntity.referenceDrawingSize = self.referenceDrawingSize
        newEntity.position = self.position
        newEntity.scale = self.scale
        newEntity.rotation = self.rotation
        newEntity.mirrored = self.mirrored
        return newEntity
    }
    
    weak var currentEntityView: DrawingEntityView?
    func makeView(context: AccountContext) -> DrawingEntityView {
        let entityView = DrawingStickerEntityView(context: context, entity: self)
        self.currentEntityView = entityView
        return entityView
    }
}

final class DrawingStickerEntityView: DrawingEntityView {
    private var stickerEntity: DrawingStickerEntity {
        return self.entity as! DrawingStickerEntity
    }
    
    var started: ((Double) -> Void)?
    
    private var currentSize: CGSize?
    private var dimensions: CGSize?
    
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
    
    private var file: TelegramMediaFile {
        return (self.entity as! DrawingStickerEntity).file
    }
    
    private func setup() {
        if let dimensions = self.file.dimensions {
            if self.file.isAnimatedSticker || self.file.isVideoSticker || self.file.mimeType == "video/webm" {
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
                let dimensions = self.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: self.context.account.postbox, file: self.file, small: false, size: dimensions.cgSize.aspectFitted(CGSize(width: 256.0, height: 256.0))))
                self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: self.context.account, fileReference: stickerPackFileReference(self.file), resource: self.file.resource).start())
            } else {
                if let animationNode = self.animationNode {
                    animationNode.visibility = false
                    self.animationNode = nil
                    animationNode.removeFromSupernode()
                    self.imageNode.isHidden = false
                    self.didSetUpAnimationNode = false
                }
                self.imageNode.setSignal(chatMessageSticker(account: self.context.account, file: self.file, small: false, synchronousLoad: false))
                self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: self.context.account, fileReference: stickerPackFileReference(self.file), resource: chatMessageStickerResource(file: self.file, small: false)).start())
            }
            
            self.dimensions = dimensions.cgSize
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
            
            if isPlaying && !self.didSetUpAnimationNode {
                self.didSetUpAnimationNode = true
                let dimensions = self.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 384.0, height: 384.0))
                let source = AnimatedStickerResourceSource(account: self.context.account, resource: self.file.resource, isVideo: self.file.isVideoSticker || self.file.mimeType == "video/webm")
                self.animationNode?.setup(source: source, width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
            
                self.cachedDisposable.set((source.cachedDataPath(width: 384, height: 384)
                |> deliverOn(Queue.concurrentDefaultQueue())).start())
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
            
            if let dimensions = self.dimensions {
                let imageSize = dimensions.aspectFitted(boundingSize)
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
            }
        }
    }
    
    override func update(animated: Bool) {
        guard let dimensions = self.stickerEntity.file.dimensions?.cgSize else {
            return
        }
        self.center = self.stickerEntity.position
        
        let size = max(10.0, min(self.stickerEntity.referenceDrawingSize.width, self.stickerEntity.referenceDrawingSize.height) * 0.45)
        
        self.bounds = CGRect(origin: .zero, size: dimensions.fitted(CGSize(width: size, height: size)))
        self.transform = CGAffineTransformScale(CGAffineTransformMakeRotation(self.stickerEntity.rotation), self.stickerEntity.scale, self.stickerEntity.scale)
    
        var transform = CATransform3DIdentity

        if self.stickerEntity.mirrored {
            transform = CATransform3DRotate(transform, .pi, 0.0, 1.0, 0.0)
            transform.m34 = -1.0 / self.imageNode.frame.width
        }
        
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0.0) {
                self.imageNode.transform = transform
                self.animationNode?.transform = transform
            }
        } else {
            self.imageNode.transform = transform
            self.animationNode?.transform = transform
        }
    
        super.update(animated: animated)
    }
    
    override func updateSelectionView() {
        guard let selectionView = self.selectionView as? DrawingStickerEntititySelectionView else {
            return
        }
        self.pushIdentityTransformForMeasurement()
     
        selectionView.transform = .identity
        let bounds = self.selectionBounds
        let center = bounds.center
        
        let scale = self.superview?.superview?.layer.value(forKeyPath: "transform.scale.x") as? CGFloat ?? 1.0
        selectionView.center = self.convert(center, to: selectionView.superview)
        
        selectionView.bounds = CGRect(origin: .zero, size: CGSize(width: (bounds.width * self.stickerEntity.scale) * scale + selectionView.selectionInset * 2.0, height: (bounds.height * self.stickerEntity.scale) * scale + selectionView.selectionInset * 2.0))
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
    
    private var currentHandle: CALayer?
    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingStickerEntity else {
            return
        }
        let location = gestureRecognizer.location(in: self)
        
        switch gestureRecognizer.state {
        case .began:
            if let sublayers = self.layer.sublayers {
                for layer in sublayers {
                    if layer.frame.contains(location) {
                        self.currentHandle = layer
                        return
                    }
                }
            }
            self.currentHandle = self.layer
        case .changed:
            let delta = gestureRecognizer.translation(in: entityView.superview)
            let parentLocation = gestureRecognizer.location(in: self.superview)
            
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
                
                let deltaAngle: CGFloat
                if self.currentHandle === self.leftHandle {
                    deltaAngle = atan2(self.center.y - parentLocation.y, self.center.x - parentLocation.x)
                } else {
                    deltaAngle = atan2(parentLocation.y - self.center.y, parentLocation.x - self.center.x)
                }
                updatedRotation = deltaAngle
            } else if self.currentHandle === self.layer {
                updatedPosition.x += delta.x
                updatedPosition.y += delta.y
            }
            
            entity.position = updatedPosition
            entity.scale = updatedScale
            entity.rotation = updatedRotation
            entityView.update()
            
            gestureRecognizer.setTranslation(.zero, in: entityView)
        case .ended:
            break
        default:
            break
        }
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
        
        switch gestureRecognizer.state {
        case .began, .changed:
            let rotation = gestureRecognizer.rotation
            entity.rotation += rotation
            entityView.update()
            
            gestureRecognizer.rotation = 0.0
        default:
            break
        }
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
        
        self.border.lineDashPattern = [12.0 / self.scale as NSNumber, 12.0 / self.scale as NSNumber]
        self.border.lineWidth = 2.0 / self.scale
        self.border.path = UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: inset, y: inset), size: CGSize(width: self.bounds.width - inset * 2.0, height: self.bounds.height - inset * 2.0))).cgPath
    }
}
