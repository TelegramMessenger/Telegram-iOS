import Foundation
import UIKit
import Display
import AccountContext

public final class DrawingBubbleEntity: DrawingEntity, Codable {
    private enum CodingKeys: String, CodingKey {
        case uuid
        case drawType
        case color
        case lineWidth
        case referenceDrawingSize
        case position
        case size
        case rotation
        case tailPosition
        case renderImage
    }
    
    enum DrawType: Codable {
        case fill
        case stroke
    }
    
    public let uuid: UUID
    public let isAnimated: Bool
    
    var drawType: DrawType
    public var color: DrawingColor
    public var lineWidth: CGFloat
    
    var referenceDrawingSize: CGSize
    public var position: CGPoint
    public var size: CGSize
    public var rotation: CGFloat
    var tailPosition: CGPoint
    
    public var center: CGPoint {
        return self.position
    }
    
    public var scale: CGFloat = 1.0
    
    public var renderImage: UIImage?
    
    init(drawType: DrawType, color: DrawingColor, lineWidth: CGFloat) {
        self.uuid = UUID()
        self.isAnimated = false
                
        self.drawType = drawType
        self.color = color
        self.lineWidth = lineWidth
        
        self.referenceDrawingSize = .zero
        self.position = .zero
        self.size = CGSize(width: 1.0, height: 1.0)
        self.rotation = 0.0
        self.tailPosition = CGPoint(x: 0.16, y: 0.18)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(UUID.self, forKey: .uuid)
        self.isAnimated = false
        self.drawType = try container.decode(DrawType.self, forKey: .drawType)
        self.color = try container.decode(DrawingColor.self, forKey: .color)
        self.lineWidth = try container.decode(CGFloat.self, forKey: .lineWidth)
        self.referenceDrawingSize = try container.decode(CGSize.self, forKey: .referenceDrawingSize)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.size = try container.decode(CGSize.self, forKey: .size)
        self.rotation = try container.decode(CGFloat.self, forKey: .rotation)
        self.tailPosition = try container.decode(CGPoint.self, forKey: .tailPosition)
        if let renderImageData = try? container.decodeIfPresent(Data.self, forKey: .renderImage) {
            self.renderImage = UIImage(data: renderImageData)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.uuid, forKey: .uuid)
        try container.encode(self.drawType, forKey: .drawType)
        try container.encode(self.color, forKey: .color)
        try container.encode(self.lineWidth, forKey: .lineWidth)
        try container.encode(self.referenceDrawingSize, forKey: .referenceDrawingSize)
        try container.encode(self.position, forKey: .position)
        try container.encode(self.size, forKey: .size)
        try container.encode(self.rotation, forKey: .rotation)
        try container.encode(self.tailPosition, forKey: .tailPosition)
        if let renderImage, let data = renderImage.pngData() {
            try container.encode(data, forKey: .renderImage)
        }
    }
        
    public func duplicate() -> DrawingEntity {
        let newEntity = DrawingBubbleEntity(drawType: self.drawType, color: self.color, lineWidth: self.lineWidth)
        newEntity.referenceDrawingSize = self.referenceDrawingSize
        newEntity.position = self.position
        newEntity.size = self.size
        newEntity.rotation = self.rotation
        return newEntity
    }
     
    public weak var currentEntityView: DrawingEntityView?
    public func makeView(context: AccountContext) -> DrawingEntityView {
        let entityView = DrawingBubbleEntityView(context: context, entity: self)
        self.currentEntityView = entityView
        return entityView
    }
    
    public func prepareForRender() {
        self.renderImage = (self.currentEntityView as? DrawingBubbleEntityView)?.getRenderImage()
    }
}

final class DrawingBubbleEntityView: DrawingEntityView {
    private var bubbleEntity: DrawingBubbleEntity {
        return self.entity as! DrawingBubbleEntity
    }
    
    private var currentSize: CGSize?
    private var currentTailPosition: CGPoint?
    
    private let shapeLayer = SimpleShapeLayer()
    
    init(context: AccountContext, entity: DrawingBubbleEntity) {
        super.init(context: context, entity: entity)
        
        self.layer.addSublayer(self.shapeLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func update(animated: Bool) {
        let size = self.bubbleEntity.size
        
        self.center = self.bubbleEntity.position
        self.bounds = CGRect(origin: .zero, size: size)
        self.transform = CGAffineTransformMakeRotation(self.bubbleEntity.rotation)
        
        if size != self.currentSize || self.bubbleEntity.tailPosition != self.currentTailPosition {
            self.currentSize = size
            self.currentTailPosition = self.bubbleEntity.tailPosition
            self.shapeLayer.frame = self.bounds
            
            let cornerRadius = max(10.0, max(self.bubbleEntity.referenceDrawingSize.width, self.bubbleEntity.referenceDrawingSize.height) * 0.045)
            let smallCornerRadius = max(5.0, max(self.bubbleEntity.referenceDrawingSize.width, self.bubbleEntity.referenceDrawingSize.height) * 0.01)
            let tailWidth = max(5.0, max(self.bubbleEntity.referenceDrawingSize.width, self.bubbleEntity.referenceDrawingSize.height) * 0.1)
            
            self.shapeLayer.path = CGPath.bubble(in: CGRect(origin: .zero, size: size), cornerRadius: cornerRadius, smallCornerRadius: smallCornerRadius, tailPosition: self.bubbleEntity.tailPosition, tailWidth: tailWidth)
        }
        
        switch self.bubbleEntity.drawType {
        case .fill:
            self.shapeLayer.fillColor = self.bubbleEntity.color.toCGColor()
            self.shapeLayer.strokeColor = UIColor.clear.cgColor
        case .stroke:
            let minLineWidth = max(10.0, max(self.bubbleEntity.referenceDrawingSize.width, self.bubbleEntity.referenceDrawingSize.height) * 0.01)
            let maxLineWidth = max(10.0, max(self.bubbleEntity.referenceDrawingSize.width, self.bubbleEntity.referenceDrawingSize.height) * 0.05)
            let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * self.bubbleEntity.lineWidth
            
            self.shapeLayer.fillColor = UIColor.clear.cgColor
            self.shapeLayer.strokeColor = self.bubbleEntity.color.toCGColor()
            self.shapeLayer.lineWidth = lineWidth
        }
        
        super.update(animated: animated)
    }
    
    fileprivate var visualLineWidth: CGFloat {
        return self.shapeLayer.lineWidth
    }
    
    private var maxLineWidth: CGFloat {
        return max(10.0, max(self.bubbleEntity.referenceDrawingSize.width, self.bubbleEntity.referenceDrawingSize.height) * 0.1)
    }
    
    fileprivate var minimumSize: CGSize {
        let minSize = min(self.bubbleEntity.referenceDrawingSize.width, self.bubbleEntity.referenceDrawingSize.height)
        return CGSize(width: minSize * 0.2, height: minSize * 0.2)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let lineWidth = self.maxLineWidth * 0.5
        let expandedBounds = self.bounds.insetBy(dx: -lineWidth, dy: -lineWidth)
        if expandedBounds.contains(point) {
            return true
        }
        return false
    }
    
    override func precisePoint(inside point: CGPoint) -> Bool {
        if case .stroke = self.bubbleEntity.drawType, var path = self.shapeLayer.path {
            path = path.copy(strokingWithWidth: maxLineWidth * 0.8, lineCap: .square, lineJoin: .bevel, miterLimit: 0.0)
            if path.contains(point) {
                return true
            } else {
                return false
            }
        } else {
            return super.precisePoint(inside: point)
        }
    }
    
    override func updateSelectionView() {
        super.updateSelectionView()
        
        guard let selectionView = self.selectionView as? DrawingBubbleEntititySelectionView else {
            return
        }
        
        selectionView.transform = CGAffineTransformMakeRotation(self.bubbleEntity.rotation)
        selectionView.setNeedsLayout()
    }
        
    override func makeSelectionView() -> DrawingEntitySelectionView {
        if let selectionView = self.selectionView {
            return selectionView
        }
        let selectionView = DrawingBubbleEntititySelectionView()
        selectionView.entityView = self
        return selectionView
    }
    
    func getRenderImage() -> UIImage? {
        let rect = self.bounds
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 1.0)
        self.drawHierarchy(in: rect, afterScreenUpdates: false)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

final class DrawingBubbleEntititySelectionView: DrawingEntitySelectionView, UIGestureRecognizerDelegate {
    private let leftHandle = SimpleShapeLayer()
    private let topLeftHandle = SimpleShapeLayer()
    private let topHandle = SimpleShapeLayer()
    private let topRightHandle = SimpleShapeLayer()
    private let rightHandle = SimpleShapeLayer()
    private let bottomLeftHandle = SimpleShapeLayer()
    private let bottomHandle = SimpleShapeLayer()
    private let bottomRightHandle = SimpleShapeLayer()
    private let tailHandle = SimpleShapeLayer()
    
    private var panGestureRecognizer: UIPanGestureRecognizer!
  
    override init(frame: CGRect) {
        let handleBounds = CGRect(origin: .zero, size: entitySelectionViewHandleSize)
        let handles = [
            self.leftHandle,
            self.topLeftHandle,
            self.topHandle,
            self.topRightHandle,
            self.rightHandle,
            self.bottomLeftHandle,
            self.bottomHandle,
            self.bottomRightHandle,
            self.tailHandle
        ]
        
        super.init(frame: frame)
        
        self.backgroundColor = .clear
        self.isOpaque = false
        
        for handle in handles {
            handle.bounds = handleBounds
            if handle === self.tailHandle {
                handle.fillColor = UIColor(rgb: 0x00ff00).cgColor
            } else {
                handle.fillColor = UIColor(rgb: 0x0a60ff).cgColor
            }
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
        return 5.5
    }
        
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    private let snapTool = DrawingEntitySnapTool()
    
    private var currentHandle: CALayer?
    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let entityView = self.entityView as? DrawingBubbleEntityView, let entity = entityView.entity as? DrawingBubbleEntity else {
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
                        return
                    }
                }
            }
            self.currentHandle = self.layer
        case .changed:
            let delta = gestureRecognizer.translation(in: entityView.superview)
            let velocity = gestureRecognizer.velocity(in: entityView.superview)
            
            var updatedSize = entity.size
            var updatedPosition = entity.position
            var updatedTailPosition = entity.tailPosition
            
            let minimumSize = entityView.minimumSize
            
            if self.currentHandle === self.leftHandle {
                updatedSize.width = max(minimumSize.width, updatedSize.width - delta.x)
                updatedPosition.x -= delta.x * -0.5
            } else if self.currentHandle === self.rightHandle {
                updatedSize.width = max(minimumSize.width, updatedSize.width + delta.x)
                updatedPosition.x += delta.x * 0.5
            } else if self.currentHandle === self.topHandle {
                updatedSize.height = max(minimumSize.height, updatedSize.height - delta.y)
                updatedPosition.y += delta.y * 0.5
            } else if self.currentHandle === self.bottomHandle {
                updatedSize.height = max(minimumSize.height, updatedSize.height + delta.y)
                updatedPosition.y += delta.y * 0.5
            } else if self.currentHandle === self.topLeftHandle {
                updatedSize.width = max(minimumSize.width, updatedSize.width - delta.x)
                updatedPosition.x -= delta.x * -0.5
                updatedSize.height =  max(minimumSize.height, updatedSize.height - delta.y)
                updatedPosition.y += delta.y * 0.5
            } else if self.currentHandle === self.topRightHandle {
                updatedSize.width = max(minimumSize.width, updatedSize.width + delta.x)
                updatedPosition.x += delta.x * 0.5
                updatedSize.height =  max(minimumSize.height, updatedSize.height - delta.y)
                updatedPosition.y += delta.y * 0.5
            } else if self.currentHandle === self.bottomLeftHandle {
                updatedSize.width = max(minimumSize.width, updatedSize.width - delta.x)
                updatedPosition.x -= delta.x * -0.5
                updatedSize.height = max(minimumSize.height, updatedSize.height + delta.y)
                updatedPosition.y += delta.y * 0.5
            } else if self.currentHandle === self.bottomRightHandle {
                updatedSize.width = max(minimumSize.width, updatedSize.width + delta.x)
                updatedPosition.x += delta.x * 0.5
                updatedSize.height = max(minimumSize.height, updatedSize.height + delta.y)
                updatedPosition.y += delta.y * 0.5
            } else if self.currentHandle === self.tailHandle {
                updatedTailPosition = CGPoint(x: max(0.0, min(1.0, updatedTailPosition.x + delta.x / updatedSize.width)), y: max(0.0, min(updatedSize.height, updatedTailPosition.y + delta.y)))
            } else if self.currentHandle === self.layer {
                updatedPosition.x += delta.x
                updatedPosition.y += delta.y
                
                updatedPosition = self.snapTool.update(entityView: entityView, velocity: velocity, delta: delta, updatedPosition: updatedPosition)
            }
            
            entity.size = updatedSize
            entity.position = updatedPosition
            entity.tailPosition = updatedTailPosition
            entityView.update(animated: false)
            
            gestureRecognizer.setTranslation(.zero, in: entityView)
        case .ended:
            self.snapTool.reset()
        case .cancelled:
            self.snapTool.reset()
        default:
            break
        }
        
        entityView.onPositionUpdated(entity.position)
    }
    
    override func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingBubbleEntity else {
            return
        }
        
        switch gestureRecognizer.state {
        case .began, .changed:
            let scale = gestureRecognizer.scale
            entity.size = CGSize(width: entity.size.width * scale, height: entity.size.height * scale)
            entityView.update()
            
            gestureRecognizer.scale = 1.0
        default:
            break
        }
    }
    
    override func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingBubbleEntity else {
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
        return self.bounds.insetBy(dx: -22.0, dy: -22.0).contains(point) || self.tailHandle.frame.contains(point)
    }
    
    override func layoutSubviews() {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingBubbleEntity else {
            return
        }
        
        let inset = self.selectionInset
        
        let bounds = CGRect(origin: .zero, size: CGSize(width: entitySelectionViewHandleSize.width / self.scale, height: entitySelectionViewHandleSize.height / self.scale))
        let handleSize = CGSize(width: 9.0 / self.scale, height: 9.0 / self.scale)
        let handlePath = CGPath(ellipseIn: CGRect(origin: CGPoint(x: (bounds.width - handleSize.width) / 2.0, y: (bounds.height - handleSize.height) / 2.0), size: handleSize), transform: nil)
        let lineWidth = (1.0 + UIScreenPixel) / self.scale

        let handles = [
            self.leftHandle,
            self.topLeftHandle,
            self.topHandle,
            self.topRightHandle,
            self.rightHandle,
            self.bottomLeftHandle,
            self.bottomHandle,
            self.bottomRightHandle,
            self.tailHandle
        ]
        
        for handle in handles {
            handle.path = handlePath
            handle.bounds = bounds
            handle.lineWidth = lineWidth
        }
        
        self.topLeftHandle.position = CGPoint(x: inset, y: inset)
        self.topHandle.position = CGPoint(x: self.bounds.midX, y: inset)
        self.topRightHandle.position = CGPoint(x: self.bounds.maxX - inset, y: inset)
        self.leftHandle.position = CGPoint(x: inset, y: self.bounds.midY)
        self.rightHandle.position = CGPoint(x: self.bounds.maxX - inset, y: self.bounds.midY)
        self.bottomLeftHandle.position = CGPoint(x: inset, y: self.bounds.maxY - inset)
        self.bottomHandle.position = CGPoint(x: self.bounds.midX, y: self.bounds.maxY - inset)
        self.bottomRightHandle.position = CGPoint(x: self.bounds.maxX - inset, y: self.bounds.maxY - inset)
        
        let selectionScale = (self.bounds.width - inset * 2.0) / (max(0.001, entity.size.width))
        self.tailHandle.position = CGPoint(x: inset + (self.bounds.width - inset * 2.0) * entity.tailPosition.x, y: self.bounds.height - inset + entity.tailPosition.y * selectionScale)
    }
    
    var isTracking: Bool {
        return gestureIsTracking(self.panGestureRecognizer)
    }
}
