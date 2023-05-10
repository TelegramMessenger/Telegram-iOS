import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import MediaEditor
import Photos

public final class DrawingMediaEntity: DrawingEntity, Codable {
    public enum Content {
        case image(UIImage, PixelDimensions)
        case video(String, PixelDimensions)
        case asset(PHAsset)
        
        var dimensions: PixelDimensions {
            switch self {
            case let .image(_, dimensions), let .video(_, dimensions):
                return dimensions
            case let .asset(asset):
                return PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight))
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case image
        case videoPath
        case assetId
        case size
        case width
        case height
        case referenceDrawingSize
        case position
        case scale
        case rotation
        case mirrored
    }
    
    public let uuid: UUID
    public let content: Content
    public let size: CGSize
    
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
        return self.size
    }
    
    public var isAnimated: Bool {
        switch self.content {
        case .image:
            return false
        case .video:
            return true
        case let .asset(asset):
            return asset.mediaType == .video
        }
    }
    
    public init(content: Content, size: CGSize) {
        self.uuid = UUID()
        self.content = content
        self.size = size
        
        self.referenceDrawingSize = .zero
        self.position = CGPoint()
        self.scale = 1.0
        self.rotation = 0.0
        self.mirrored = false
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(UUID.self, forKey: .uuid)
        self.size = try container.decode(CGSize.self, forKey: .size)
        let width = try container.decode(Int32.self, forKey: .width)
        let height = try container.decode(Int32.self, forKey: .height)
        if let videoPath = try container.decodeIfPresent(String.self, forKey: .videoPath) {
            self.content = .video(videoPath, PixelDimensions(width: width, height: height))
        } else if let imageData = try container.decodeIfPresent(Data.self, forKey: .image), let image = UIImage(data: imageData) {
            self.content = .image(image, PixelDimensions(width: width, height: height))
        } else if let _ = try container.decodeIfPresent(String.self, forKey: .assetId) {
            fatalError()
            //self.content = .asset()
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
        case let .video(videoPath, dimensions):
            try container.encode(videoPath, forKey: .videoPath)
            try container.encode(dimensions.width, forKey: .width)
            try container.encode(dimensions.height, forKey: .height)
        case let .image(image, dimensions):
            try container.encodeIfPresent(image.jpegData(compressionQuality: 0.9), forKey: .image)
            try container.encode(dimensions.width, forKey: .width)
            try container.encode(dimensions.height, forKey: .height)
        case let .asset(asset):
            try container.encode(asset.localIdentifier, forKey: .assetId)
        }
        try container.encode(self.size, forKey: .size)
        try container.encode(self.referenceDrawingSize, forKey: .referenceDrawingSize)
        try container.encode(self.position, forKey: .position)
        try container.encode(self.scale, forKey: .scale)
        try container.encode(self.rotation, forKey: .rotation)
        try container.encode(self.mirrored, forKey: .mirrored)
    }
        
    public func duplicate() -> DrawingEntity {
        let newEntity = DrawingMediaEntity(content: self.content, size: self.size)
        newEntity.referenceDrawingSize = self.referenceDrawingSize
        newEntity.position = self.position
        newEntity.scale = self.scale
        newEntity.rotation = self.rotation
        newEntity.mirrored = self.mirrored
        return newEntity
    }
    
    public weak var currentEntityView: DrawingEntityView?
    public func makeView(context: AccountContext) -> DrawingEntityView {
        let entityView = DrawingMediaEntityView(context: context, entity: self)
        self.currentEntityView = entityView
        return entityView
    }
    
    public func prepareForRender() {
    }
}

public final class DrawingMediaEntityView: DrawingEntityView {
    private var mediaEntity: DrawingMediaEntity {
        return self.entity as! DrawingMediaEntity
    }
    
    var started: ((Double) -> Void)?
    
    private var currentSize: CGSize?
    private var isVisible = true
    private var isPlaying = false
    
    public var previewView: MediaEditorPreviewView? {
        didSet {
            if let previewView = self.previewView {
                previewView.isUserInteractionEnabled = false
                self.addSubview(previewView)
            }
        }
    }
    
    init(context: AccountContext, entity: DrawingMediaEntity) {
        super.init(context: context, entity: entity)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {

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
        
    }
    
    override func resetToStart() {
        self.isVisible = false
        self.isPlaying = false
    }
    
    override func updateVisibility(_ visibility: Bool) {
        self.isVisible = visibility
        self.applyVisibility()
    }
    
    private func applyVisibility() {
        let isPlaying = self.isVisible
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            
        }
    }
    
    private var didApplyVisibility = false
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
                
        if size.width > 0 && self.currentSize != size {
            self.currentSize = size
            self.previewView?.frame = CGRect(origin: .zero, size: size)
//            let sideSize: CGFloat = size.width
//            let boundingSize = CGSize(width: sideSize, height: sideSize)
//
//            let imageSize = self.dimensions.aspectFitted(boundingSize)
//            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
//            self.imageNode.frame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: (size.height - imageSize.height) / 2.0), size: imageSize)
//            if let animationNode = self.animationNode {
//                animationNode.frame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: (size.height - imageSize.height) / 2.0), size: imageSize)
//                animationNode.updateLayout(size: imageSize)
//
//                if !self.didApplyVisibility {
//                    self.didApplyVisibility = true
//                    self.applyVisibility()
//                }
//            }
            self.update(animated: false)
        }
    }
            
    override func update(animated: Bool) {
        self.center = self.mediaEntity.position
        
        let size = self.mediaEntity.baseSize
        let scale = self.mediaEntity.scale
        
        self.bounds = CGRect(origin: .zero, size: size)
        self.transform = CGAffineTransformScale(CGAffineTransformMakeRotation(self.mediaEntity.rotation), scale, scale)
    
        self.previewView?.layer.transform = CATransform3DMakeScale(self.mediaEntity.mirrored ? -1.0 : 1.0, 1.0, 1.0)
        self.previewView?.frame = self.bounds
    
        super.update(animated: animated)
    }
    
    override func updateSelectionView() {

    }
        
    override func makeSelectionView() -> DrawingEntitySelectionView? {
        return nil
    }
    
    @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let delta = gestureRecognizer.translation(in: self.superview)
        var updatedPosition = self.mediaEntity.position
        
        switch gestureRecognizer.state {
        case .began, .changed:
            updatedPosition.x += delta.x
            updatedPosition.y += delta.y
            
            gestureRecognizer.setTranslation(.zero, in: self.superview)
        default:
            break
        }
        
        self.mediaEntity.position = updatedPosition
        self.update(animated: false)
    }
    
    @objc func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began, .changed:
            let scale = gestureRecognizer.scale
            self.mediaEntity.scale = self.mediaEntity.scale * scale
            self.update(animated: false)

            gestureRecognizer.scale = 1.0
        default:
            break
        }
    }
    
    @objc func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        var updatedRotation = self.mediaEntity.rotation
        var rotation: CGFloat = 0.0
        
        switch gestureRecognizer.state {
        case .began:
            break
        case .changed:
            rotation = gestureRecognizer.rotation
            updatedRotation += rotation
            
            gestureRecognizer.rotation = 0.0
        case .ended, .cancelled:
            break
        default:
            break
        }
        
        self.mediaEntity.rotation = updatedRotation
        self.update(animated: false)
    }
}

//final class DrawingStickerEntititySelectionView: DrawingEntitySelectionView, UIGestureRecognizerDelegate {
//    private let border = SimpleShapeLayer()
//    private let leftHandle = SimpleShapeLayer()
//    private let rightHandle = SimpleShapeLayer()
//
//    private var panGestureRecognizer: UIPanGestureRecognizer!
//
//    override init(frame: CGRect) {
//        let handleBounds = CGRect(origin: .zero, size: entitySelectionViewHandleSize)
//        let handles = [
//            self.leftHandle,
//            self.rightHandle
//        ]
//
//        super.init(frame: frame)
//
//        self.backgroundColor = .clear
//        self.isOpaque = false
//
//        self.border.lineCap = .round
//        self.border.fillColor = UIColor.clear.cgColor
//        self.border.strokeColor = UIColor(rgb: 0xffffff, alpha: 0.5).cgColor
//        self.border.shadowColor = UIColor.black.cgColor
//        self.border.shadowRadius = 1.0
//        self.border.shadowOpacity = 0.5
//        self.border.shadowOffset = CGSize()
//        self.layer.addSublayer(self.border)
//
//        for handle in handles {
//            handle.bounds = handleBounds
//            handle.fillColor = UIColor(rgb: 0x0a60ff).cgColor
//            handle.strokeColor = UIColor(rgb: 0xffffff).cgColor
//            handle.rasterizationScale = UIScreen.main.scale
//            handle.shouldRasterize = true
//
//            self.layer.addSublayer(handle)
//        }
//
//        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
//        panGestureRecognizer.delegate = self
//        self.addGestureRecognizer(panGestureRecognizer)
//        self.panGestureRecognizer = panGestureRecognizer
//
//        self.snapTool.onSnapXUpdated = { [weak self] snapped in
//            if let strongSelf = self, let entityView = strongSelf.entityView {
//                entityView.onSnapToXAxis(snapped)
//            }
//        }
//
//        self.snapTool.onSnapYUpdated = { [weak self] snapped in
//            if let strongSelf = self, let entityView = strongSelf.entityView {
//                entityView.onSnapToYAxis(snapped)
//            }
//        }
//
//        self.snapTool.onSnapRotationUpdated = { [weak self] snappedAngle in
//            if let strongSelf = self, let entityView = strongSelf.entityView {
//                entityView.onSnapToAngle(snappedAngle)
//            }
//        }
//    }
//
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    var scale: CGFloat = 1.0 {
//        didSet {
//            self.setNeedsLayout()
//        }
//    }
//
//    override var selectionInset: CGFloat {
//        return 18.0
//    }
//
//    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
//        return true
//    }
//
//    private let snapTool = DrawingEntitySnapTool()
//
//    private var currentHandle: CALayer?
//    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
//        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingStickerEntity else {
//            return
//        }
//        let location = gestureRecognizer.location(in: self)
//
//        switch gestureRecognizer.state {
//        case .began:
//            self.snapTool.maybeSkipFromStart(entityView: entityView, position: entity.position)
//
//            if let sublayers = self.layer.sublayers {
//                for layer in sublayers {
//                    if layer.frame.contains(location) {
//                        self.currentHandle = layer
//                        self.snapTool.maybeSkipFromStart(entityView: entityView, rotation: entity.rotation)
//                        return
//                    }
//                }
//            }
//            self.currentHandle = self.layer
//        case .changed:
//            let delta = gestureRecognizer.translation(in: entityView.superview)
//            let parentLocation = gestureRecognizer.location(in: self.superview)
//            let velocity = gestureRecognizer.velocity(in: entityView.superview)
//
//            var updatedPosition = entity.position
//            var updatedScale = entity.scale
//            var updatedRotation = entity.rotation
//            if self.currentHandle === self.leftHandle || self.currentHandle === self.rightHandle {
//                var deltaX = gestureRecognizer.translation(in: self).x
//                if self.currentHandle === self.leftHandle {
//                    deltaX *= -1.0
//                }
//                let scaleDelta = (self.bounds.size.width + deltaX * 2.0) / self.bounds.size.width
//                updatedScale *= scaleDelta
//
//                let newAngle: CGFloat
//                if self.currentHandle === self.leftHandle {
//                    newAngle = atan2(self.center.y - parentLocation.y, self.center.x - parentLocation.x)
//                } else {
//                    newAngle = atan2(parentLocation.y - self.center.y, parentLocation.x - self.center.x)
//                }
//
//             //   let delta = newAngle - updatedRotation
//                updatedRotation = newAngle// self.snapTool.update(entityView: entityView, velocity: 0.0, delta: delta, updatedRotation: newAngle)
//            } else if self.currentHandle === self.layer {
//                updatedPosition.x += delta.x
//                updatedPosition.y += delta.y
//
//                updatedPosition = self.snapTool.update(entityView: entityView, velocity: velocity, delta: delta, updatedPosition: updatedPosition)
//            }
//
//            entity.position = updatedPosition
//            entity.scale = updatedScale
//            entity.rotation = updatedRotation
//            entityView.update()
//
//            gestureRecognizer.setTranslation(.zero, in: entityView)
//        case .ended, .cancelled:
//            self.snapTool.reset()
//            if self.currentHandle != nil {
//                self.snapTool.rotationReset()
//            }
//        default:
//            break
//        }
//
//        entityView.onPositionUpdated(entity.position)
//    }
//
//    override func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
//        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingStickerEntity else {
//            return
//        }
//
//        switch gestureRecognizer.state {
//        case .began, .changed:
//            let scale = gestureRecognizer.scale
//            entity.scale = entity.scale * scale
//            entityView.update()
//
//            gestureRecognizer.scale = 1.0
//        default:
//            break
//        }
//    }
//
//    override func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
//        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingStickerEntity else {
//            return
//        }
//
//        let velocity = gestureRecognizer.velocity
//        var updatedRotation = entity.rotation
//        var rotation: CGFloat = 0.0
//
//        switch gestureRecognizer.state {
//        case .began:
//            self.snapTool.maybeSkipFromStart(entityView: entityView, rotation: entity.rotation)
//        case .changed:
//            rotation = gestureRecognizer.rotation
//            updatedRotation += rotation
//
//            gestureRecognizer.rotation = 0.0
//        case .ended, .cancelled:
//            self.snapTool.rotationReset()
//        default:
//            break
//        }
//
//        updatedRotation = self.snapTool.update(entityView: entityView, velocity: velocity, delta: rotation, updatedRotation: updatedRotation)
//        entity.rotation = updatedRotation
//        entityView.update()
//
//        entityView.onPositionUpdated(entity.position)
//    }
//
//    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
//        return self.bounds.insetBy(dx: -22.0,  dy: -22.0).contains(point)
//    }
//
//    override func layoutSubviews() {
//        let inset = self.selectionInset - 10.0
//
//        let bounds = CGRect(origin: .zero, size: CGSize(width: entitySelectionViewHandleSize.width / self.scale, height: entitySelectionViewHandleSize.height / self.scale))
//        let handleSize = CGSize(width: 9.0 / self.scale, height: 9.0 / self.scale)
//        let handlePath = CGPath(ellipseIn: CGRect(origin: CGPoint(x: (bounds.width - handleSize.width) / 2.0, y: (bounds.height - handleSize.height) / 2.0), size: handleSize), transform: nil)
//        let lineWidth = (1.0 + UIScreenPixel) / self.scale
//
//        let handles = [
//            self.leftHandle,
//            self.rightHandle
//        ]
//
//        for handle in handles {
//            handle.path = handlePath
//            handle.bounds = bounds
//            handle.lineWidth = lineWidth
//        }
//
//        self.leftHandle.position = CGPoint(x: inset, y: self.bounds.midY)
//        self.rightHandle.position = CGPoint(x: self.bounds.maxX - inset, y: self.bounds.midY)
//
//
//        let radius = (self.bounds.width - inset * 2.0) / 2.0
//        let circumference: CGFloat = 2.0 * .pi * radius
//        let count = 10
//        let relativeDashLength: CGFloat = 0.25
//        let dashLength = circumference / CGFloat(count)
//        self.border.lineDashPattern = [dashLength * relativeDashLength, dashLength * relativeDashLength] as [NSNumber]
//
//        self.border.lineWidth = 2.0 / self.scale
//        self.border.path = UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: inset, y: inset), size: CGSize(width: self.bounds.width - inset * 2.0, height: self.bounds.height - inset * 2.0))).cgPath
//    }
//}
