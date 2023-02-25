import Foundation
import UIKit
import Display
import AccountContext

public final class DrawingVectorEntity: DrawingEntity, Codable {
    private enum CodingKeys: String, CodingKey {
        case uuid
        case type
        case color
        case lineWidth
        case drawingSize
        case referenceDrawingSize
        case start
        case mid
        case end
        case renderImage
    }
    
    public enum VectorType: Codable {
        case line
        case oneSidedArrow
        case twoSidedArrow
    }
    
    public let uuid: UUID
    public let isAnimated: Bool
    
    var type: VectorType
    public var color: DrawingColor
    public var lineWidth: CGFloat
    
    public var drawingSize: CGSize
    var referenceDrawingSize: CGSize
    var start: CGPoint
    var mid: (CGFloat, CGFloat)
    var end: CGPoint
    
    var _cachedMidPoint: (start: CGPoint, end: CGPoint, midLength: CGFloat, midHeight: CGFloat, midPoint: CGPoint)?
    var midPoint: CGPoint {
        if let (start, end, midLength, midHeight, midPoint) = self._cachedMidPoint, start == self.start, end == self.end, midLength == self.mid.0, midHeight == self.mid.1 {
            return midPoint
        } else {
            let midPoint = midPointPositionFor(start: self.start, end: self.end, length: self.mid.0, height: self.mid.1)
            self._cachedMidPoint = (self.start, self.end, self.mid.0, self.mid.1, midPoint)
            return midPoint
        }
    }
    
    public var center: CGPoint {
        return self.start
    }
    
    public var scale: CGFloat = 1.0
    
    public var renderImage: UIImage?
    
    init(type: VectorType, color: DrawingColor, lineWidth: CGFloat) {
        self.uuid = UUID()
        self.isAnimated = false
        
        self.type = type
        self.color = color
        self.lineWidth = lineWidth
        
        self.drawingSize = .zero
        self.referenceDrawingSize = .zero
        self.start = CGPoint()
        self.mid = (0.5, 0.0)
        self.end = CGPoint()
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(UUID.self, forKey: .uuid)
        self.isAnimated = false
        self.type = try container.decode(VectorType.self, forKey: .type)
        self.color = try container.decode(DrawingColor.self, forKey: .color)
        self.lineWidth = try container.decode(CGFloat.self, forKey: .lineWidth)
        self.drawingSize = try container.decode(CGSize.self, forKey: .drawingSize)
        self.referenceDrawingSize = try container.decode(CGSize.self, forKey: .referenceDrawingSize)
        self.start = try container.decode(CGPoint.self, forKey: .start)
        let mid = try container.decode(CGPoint.self, forKey: .mid)
        self.mid = (mid.x, mid.y)
        self.end = try container.decode(CGPoint.self, forKey: .end)
        if let renderImageData = try? container.decodeIfPresent(Data.self, forKey: .renderImage) {
            self.renderImage = UIImage(data: renderImageData)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.uuid, forKey: .uuid)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.color, forKey: .color)
        try container.encode(self.lineWidth, forKey: .lineWidth)
        try container.encode(self.drawingSize, forKey: .drawingSize)
        try container.encode(self.referenceDrawingSize, forKey: .referenceDrawingSize)
        try container.encode(self.start, forKey: .start)
        try container.encode(CGPoint(x: self.mid.0, y: self.mid.1), forKey: .mid)
        try container.encode(self.end, forKey: .end)
        if let renderImage, let data = renderImage.pngData() {
            try container.encode(data, forKey: .renderImage)
        }
    }
    
    public func duplicate() -> DrawingEntity {
        let newEntity = DrawingVectorEntity(type: self.type, color: self.color, lineWidth: self.lineWidth)
        newEntity.drawingSize = self.drawingSize
        newEntity.referenceDrawingSize = self.referenceDrawingSize
        newEntity.start = self.start
        newEntity.mid = self.mid
        newEntity.end = self.end
        return newEntity
    }
    
    public weak var currentEntityView: DrawingEntityView?
    public func makeView(context: AccountContext) -> DrawingEntityView {
        let entityView = DrawingVectorEntityView(context: context, entity: self)
        self.currentEntityView = entityView
        return entityView
    }
    
    public func prepareForRender() {
        self.renderImage = (self.currentEntityView as? DrawingVectorEntityView)?.getRenderImage()
    }
}

final class DrawingVectorEntityView: DrawingEntityView {
    private var vectorEntity: DrawingVectorEntity {
        return self.entity as! DrawingVectorEntity
    }
    
    fileprivate let shapeLayer = SimpleShapeLayer()
    
    init(context: AccountContext, entity: DrawingVectorEntity) {
        super.init(context: context, entity: entity)
        
        self.layer.addSublayer(self.shapeLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var selectionBounds: CGRect {
        return self.shapeLayer.path?.boundingBox ?? self.bounds
    }
        
    private var maxLineWidth: CGFloat {
        return max(10.0, max(self.vectorEntity.referenceDrawingSize.width, self.vectorEntity.referenceDrawingSize.height) * 0.1)
    }
    
    override func update(animated: Bool) {
        self.center = CGPoint(x: self.vectorEntity.drawingSize.width * 0.5, y: self.vectorEntity.drawingSize.height * 0.5)
        self.bounds = CGRect(origin: .zero, size: self.vectorEntity.drawingSize)
    
        let minLineWidth = max(10.0, max(self.vectorEntity.referenceDrawingSize.width, self.vectorEntity.referenceDrawingSize.height) * 0.01)
        let maxLineWidth = max(10.0, max(self.vectorEntity.referenceDrawingSize.width, self.vectorEntity.referenceDrawingSize.height) * 0.05)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * self.vectorEntity.lineWidth
        
        self.shapeLayer.path = CGPath.curve(
            start: self.vectorEntity.start,
            end: self.vectorEntity.end,
            mid: self.vectorEntity.midPoint,
            lineWidth: lineWidth,
            arrowSize: self.vectorEntity.type == .line ? nil : CGSize(width: lineWidth * 1.5, height: lineWidth * 3.0),
            twoSided: self.vectorEntity.type == .twoSidedArrow
        )
        self.shapeLayer.fillColor = self.vectorEntity.color.toCGColor()
        
        super.update(animated: animated)
    }
    
    override func updateSelectionView() {
        guard let selectionView = self.selectionView as? DrawingVectorEntititySelectionView else {
            return
        }
        
        let scale = self.superview?.superview?.layer.value(forKeyPath: "transform.scale.x") as? CGFloat ?? 1.0
        
        let drawingSize = self.vectorEntity.drawingSize
        selectionView.bounds =  CGRect(origin: .zero, size: drawingSize)
        selectionView.center = CGPoint(x: drawingSize.width * 0.5 * scale, y: drawingSize.height * 0.5 * scale)
        selectionView.transform = CGAffineTransform(scaleX: scale, y: scale)
        selectionView.scale = scale
    }
    
    override func precisePoint(inside point: CGPoint) -> Bool {
        if let path = self.shapeLayer.path {
            if path.contains(point) {
                return true
            } else {
                let expandedPath = CGPath.curve(
                    start: self.vectorEntity.start,
                    end: self.vectorEntity.end,
                    mid: self.vectorEntity.midPoint,
                    lineWidth: self.maxLineWidth * 0.8,
                    arrowSize: nil,
                    twoSided: false
                )
                return expandedPath.contains(point)
            }
        } else {
            return super.precisePoint(inside: point)
        }
    }
        
    override func makeSelectionView() -> DrawingEntitySelectionView {
        if let selectionView = self.selectionView {
            return selectionView
        }
        let selectionView = DrawingVectorEntititySelectionView()
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

private func midPointPositionFor(start: CGPoint, end: CGPoint, length: CGFloat, height: CGFloat) -> CGPoint {
    let distance = end.distance(to: start)
    let angle = start.angle(to: end)
    let p1 = start.pointAt(distance: distance * length, angle: angle)
    let p2 = p1.pointAt(distance: distance * height, angle: angle + .pi * 0.5)
    return p2
}

final class DrawingVectorEntititySelectionView: DrawingEntitySelectionView, UIGestureRecognizerDelegate {
    private let startHandle = SimpleShapeLayer()
    private let midHandle = SimpleShapeLayer()
    private let endHandle = SimpleShapeLayer()
 
    private var panGestureRecognizer: UIPanGestureRecognizer!
 
    var scale: CGFloat = 1.0 {
        didSet {
            self.setNeedsLayout()
        }
    }
        
    override init(frame: CGRect) {
        let handleBounds = CGRect(origin: .zero, size: entitySelectionViewHandleSize)
        self.startHandle.bounds = handleBounds
        self.startHandle.fillColor = UIColor(rgb: 0x0a60ff).cgColor
        self.startHandle.strokeColor = UIColor(rgb: 0xffffff).cgColor
        self.startHandle.rasterizationScale = UIScreen.main.scale
        self.startHandle.shouldRasterize = true
        
        self.midHandle.bounds = handleBounds
        self.midHandle.fillColor = UIColor(rgb: 0x00ff00).cgColor
        self.midHandle.strokeColor = UIColor(rgb: 0xffffff).cgColor
        self.midHandle.rasterizationScale = UIScreen.main.scale
        self.midHandle.shouldRasterize = true
        
        self.endHandle.bounds = handleBounds
        self.endHandle.fillColor = UIColor(rgb: 0x0a60ff).cgColor
        self.endHandle.strokeColor = UIColor(rgb: 0xffffff).cgColor
        self.endHandle.rasterizationScale = UIScreen.main.scale
        self.endHandle.shouldRasterize = true
        
        super.init(frame: frame)
        
        self.backgroundColor = .clear
        self.isOpaque = false
                
        self.layer.addSublayer(self.startHandle)
        self.layer.addSublayer(self.midHandle)
        self.layer.addSublayer(self.endHandle)
       
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        panGestureRecognizer.delegate = self
        self.addGestureRecognizer(panGestureRecognizer)
        self.panGestureRecognizer = panGestureRecognizer
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    private var currentHandle: CALayer?
    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingVectorEntity else {
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
            let delta = gestureRecognizer.translation(in: entityView)
            
            var updatedStart = entity.start
            var updatedMid = entity.mid
            var updatedEnd = entity.end
            
            if self.currentHandle === self.startHandle {
                updatedStart.x += delta.x
                updatedStart.y += delta.y
            } else if self.currentHandle === self.endHandle {
                updatedEnd.x += delta.x
                updatedEnd.y += delta.y
            } else if self.currentHandle === self.midHandle {
                var updatedMidPoint = entity.midPoint
                updatedMidPoint.x += delta.x
                updatedMidPoint.y += delta.y
                
                let distance = updatedStart.distance(to: updatedEnd)
                let pointOnLine = updatedMidPoint.perpendicularPointOnLine(start: updatedStart, end: updatedEnd)
                
                let angle = updatedStart.angle(to: updatedEnd)
                let midAngle = updatedStart.angle(to: updatedMidPoint)
                var height = updatedMidPoint.distance(to: pointOnLine) / distance
                var deltaAngle = midAngle - angle
                if deltaAngle > .pi {
                    deltaAngle = angle - 2 * .pi
                } else if deltaAngle < -.pi {
                    deltaAngle = angle + 2 * .pi
                }
                if deltaAngle < 0.0 {
                    height *= -1.0
                }
                let length = updatedStart.distance(to: pointOnLine) / distance
                updatedMid = (length, height)
            } else if self.currentHandle === self.layer {
                updatedStart.x += delta.x
                updatedStart.y += delta.y
                updatedEnd.x += delta.x
                updatedEnd.y += delta.y
            }
            
            entity.start = updatedStart
            entity.mid = updatedMid
            entity.end = updatedEnd
            entityView.update()
            
            gestureRecognizer.setTranslation(.zero, in: entityView)
        case .ended:
            break
        default:
            break
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if self.startHandle.frame.contains(point) || self.midHandle.frame.contains(point) || self.endHandle.frame.contains(point) {
            return true
        } else if let entityView = self.entityView as? DrawingVectorEntityView, let path = entityView.shapeLayer.path {
            return path.contains(self.convert(point, to: entityView))
        }
        return false
    }
    
    override func layoutSubviews() {
        guard let entityView = self.entityView as? DrawingVectorEntityView, let entity = entityView.entity as? DrawingVectorEntity else {
            return
        }
        
        let bounds = CGRect(origin: .zero, size: CGSize(width: entitySelectionViewHandleSize.width / self.scale, height: entitySelectionViewHandleSize.height / self.scale))
        let handleSize = CGSize(width: 9.0 / self.scale, height: 9.0 / self.scale)
        let handlePath = CGPath(ellipseIn: CGRect(origin: CGPoint(x: (bounds.width - handleSize.width) / 2.0, y: (bounds.height - handleSize.height) / 2.0), size: handleSize), transform: nil)
        let lineWidth = (1.0 + UIScreenPixel) / self.scale
        
        self.startHandle.path = handlePath
        self.startHandle.position = entity.start
        self.startHandle.bounds = bounds
        self.startHandle.lineWidth = lineWidth
        
        self.midHandle.path = handlePath
        self.midHandle.position = entity.midPoint
        self.midHandle.bounds = bounds
        self.midHandle.lineWidth = lineWidth
        
        self.endHandle.path = handlePath
        self.endHandle.position = entity.end
        self.endHandle.bounds = bounds
        self.endHandle.lineWidth = lineWidth
    }
    
    var isTracking: Bool {
        return gestureIsTracking(self.panGestureRecognizer)
    }
}
