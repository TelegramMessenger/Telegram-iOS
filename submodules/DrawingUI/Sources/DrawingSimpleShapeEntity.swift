import Foundation
import UIKit
import Display
import AccountContext

final class DrawingSimpleShapeEntity: DrawingEntity {
    public enum ShapeType {
        case rectangle
        case ellipse
        case star
    }
    
    public enum DrawType {
        case fill
        case stroke
    }
    
    let uuid: UUID
    let isAnimated: Bool
    
    var shapeType: ShapeType
    var drawType: DrawType
    var color: DrawingColor
    var lineWidth: CGFloat
    
    var referenceDrawingSize: CGSize
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat
    
    init(shapeType: ShapeType, drawType: DrawType, color: DrawingColor, lineWidth: CGFloat) {
        self.uuid = UUID()
        self.isAnimated = false
        
        self.shapeType = shapeType
        self.drawType = drawType
        self.color = color
        self.lineWidth = lineWidth
        
        self.referenceDrawingSize = .zero
        self.position = .zero
        self.size = CGSize(width: 1.0, height: 1.0)
        self.rotation = 0.0
    }
    
    var center: CGPoint {
        return self.position
    }
    
    func duplicate() -> DrawingEntity {
        let newEntity = DrawingSimpleShapeEntity(shapeType: self.shapeType, drawType: self.drawType, color: self.color, lineWidth: self.lineWidth)
        newEntity.referenceDrawingSize = self.referenceDrawingSize
        newEntity.position = self.position
        newEntity.size = self.size
        newEntity.rotation = self.rotation
        return newEntity
    }
    
    weak var currentEntityView: DrawingEntityView?
    func makeView(context: AccountContext) -> DrawingEntityView {
        let entityView = DrawingSimpleShapeEntityView(context: context, entity: self)
        self.currentEntityView = entityView
        return entityView
    }
}

final class DrawingSimpleShapeEntityView: DrawingEntityView {
    private var shapeEntity: DrawingSimpleShapeEntity {
        return self.entity as! DrawingSimpleShapeEntity
    }
    
    private var currentShape: DrawingSimpleShapeEntity.ShapeType?
    private var currentSize: CGSize?
    
    private let shapeLayer = SimpleShapeLayer()
    
    init(context: AccountContext, entity: DrawingSimpleShapeEntity) {
        super.init(context: context, entity: entity)
    
        self.layer.addSublayer(self.shapeLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func update(animated: Bool) {
        let shapeType = self.shapeEntity.shapeType
        let size = self.shapeEntity.size
        
        self.center = self.shapeEntity.position
        self.bounds = CGRect(origin: .zero, size: size)
        self.transform = CGAffineTransformMakeRotation(self.shapeEntity.rotation)
        
        if shapeType != self.currentShape || size != self.currentSize {
            self.currentShape = shapeType
            self.currentSize = size
            self.shapeLayer.frame = self.bounds
            
            switch shapeType {
            case .rectangle:
                self.shapeLayer.path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
            case .ellipse:
                self.shapeLayer.path = CGPath(ellipseIn: CGRect(origin: .zero, size: size), transform: nil)
            case .star:
                self.shapeLayer.path = CGPath.star(in: CGRect(origin: .zero, size: size), extrusion: size.width * 0.2, points: 5)
            }
        }
        
        switch self.shapeEntity.drawType {
        case .fill:
            self.shapeLayer.fillColor = self.shapeEntity.color.toCGColor()
            self.shapeLayer.strokeColor = UIColor.clear.cgColor
        case .stroke:
            let minLineWidth = max(10.0, min(self.shapeEntity.referenceDrawingSize.width, self.shapeEntity.referenceDrawingSize.height) * 0.02)
            let maxLineWidth = max(10.0, min(self.shapeEntity.referenceDrawingSize.width, self.shapeEntity.referenceDrawingSize.height) * 0.1)
            let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * self.shapeEntity.lineWidth
            
            self.shapeLayer.fillColor = UIColor.clear.cgColor
            self.shapeLayer.strokeColor = self.shapeEntity.color.toCGColor()
            self.shapeLayer.lineWidth = lineWidth
        }
        
        super.update(animated: animated)
    }
    
    fileprivate var visualLineWidth: CGFloat {
        return self.shapeLayer.lineWidth
    }
    
    override func precisePoint(inside point: CGPoint) -> Bool {
        if case .stroke = self.shapeEntity.drawType, var path = self.shapeLayer.path {
            path = path.copy(strokingWithWidth: 20.0, lineCap: .square, lineJoin: .bevel, miterLimit: 0.0)
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
        
        guard let selectionView = self.selectionView as? DrawingSimpleShapeEntititySelectionView else {
            return
        }
        
//        let scale = self.superview?.superview?.layer.value(forKeyPath: "transform.scale.x") as? CGFloat ?? 1.0
//        selectionView.scale = scale
        
        selectionView.transform = CGAffineTransformMakeRotation(self.shapeEntity.rotation)
    }
        
    override func makeSelectionView() -> DrawingEntitySelectionView {
        if let selectionView = self.selectionView {
            return selectionView
        }
        let selectionView = DrawingSimpleShapeEntititySelectionView()
        selectionView.entityView = self
        return selectionView
    }
}

func gestureIsTracking(_ gestureRecognizer: UIPanGestureRecognizer) -> Bool {
    return [.began, .changed].contains(gestureRecognizer.state)
}

final class DrawingSimpleShapeEntititySelectionView: DrawingEntitySelectionView, UIGestureRecognizerDelegate {
    private let leftHandle = SimpleShapeLayer()
    private let topLeftHandle = SimpleShapeLayer()
    private let topHandle = SimpleShapeLayer()
    private let topRightHandle = SimpleShapeLayer()
    private let rightHandle = SimpleShapeLayer()
    private let bottomLeftHandle = SimpleShapeLayer()
    private let bottomHandle = SimpleShapeLayer()
    private let bottomRightHandle = SimpleShapeLayer()
    
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
            self.bottomRightHandle
        ]
        
        super.init(frame: frame)
        
        self.backgroundColor = .clear
        self.isOpaque = false
        
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
        return 5.5
    }
        
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    private var currentHandle: CALayer?
    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingSimpleShapeEntity else {
            return
        }
        let isAspectLocked = [.star].contains(entity.shapeType)
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
            
            var updatedSize = entity.size
            var updatedPosition = entity.position
            
            if self.currentHandle === self.leftHandle {
                let deltaX = delta.x * cos(entity.rotation)
                let deltaY = delta.x * sin(entity.rotation)
                
                updatedSize.width -= deltaX
                updatedPosition.x -= deltaX * -0.5
                updatedPosition.y -= deltaY * -0.5
                
                if isAspectLocked {
                    updatedSize.height -= delta.x
                }
            } else if self.currentHandle === self.rightHandle {
                let deltaX = delta.x * cos(entity.rotation)
                let deltaY = delta.x * sin(entity.rotation)
                
                updatedSize.width += deltaX
                updatedPosition.x += deltaX * 0.5
                updatedPosition.y += deltaY * 0.5
                if isAspectLocked {
                    updatedSize.height += delta.x
                }
            } else if self.currentHandle === self.topHandle {
                let deltaX = delta.y * sin(entity.rotation)
                let deltaY = delta.y * cos(entity.rotation)
                
                updatedSize.height -= deltaY
                updatedPosition.x += deltaX * 0.5
                updatedPosition.y += deltaY * 0.5
                if isAspectLocked {
                    updatedSize.width -= delta.y
                }
            } else if self.currentHandle === self.bottomHandle {
                let deltaX = delta.y * sin(entity.rotation)
                let deltaY = delta.y * cos(entity.rotation)
                
                updatedSize.height += deltaY
                updatedPosition.x += deltaX * 0.5
                updatedPosition.y += deltaY * 0.5
                if isAspectLocked {
                    updatedSize.width += delta.y
                }
            } else if self.currentHandle === self.topLeftHandle {
                var delta = delta
                if isAspectLocked {
                    delta = CGPoint(x: delta.x, y: delta.x)
                }
                updatedSize.width -= delta.x
                updatedPosition.x -= delta.x * -0.5
                updatedSize.height -= delta.y
                updatedPosition.y += delta.y * 0.5
            } else if self.currentHandle === self.topRightHandle {
                var delta = delta
                if isAspectLocked {
                    delta = CGPoint(x: delta.x, y: -delta.x)
                }
                updatedSize.width += delta.x
                updatedPosition.x += delta.x * 0.5
                updatedSize.height -= delta.y
                updatedPosition.y += delta.y * 0.5
            } else if self.currentHandle === self.bottomLeftHandle {
                var delta = delta
                if isAspectLocked {
                    delta = CGPoint(x: delta.x, y: -delta.x)
                }
                updatedSize.width -= delta.x
                updatedPosition.x -= delta.x * -0.5
                updatedSize.height += delta.y
                updatedPosition.y += delta.y * 0.5
            } else if self.currentHandle === self.bottomRightHandle {
                var delta = delta
                if isAspectLocked {
                    delta = CGPoint(x: delta.x, y: delta.x)
                }
                updatedSize.width += delta.x
                updatedPosition.x += delta.x * 0.5
                updatedSize.height += delta.y
                updatedPosition.y += delta.y * 0.5
            } else if self.currentHandle === self.layer {
                updatedPosition.x += delta.x
                updatedPosition.y += delta.y
            }
            
            entity.size = updatedSize
            entity.position = updatedPosition
            entityView.update()
            
            gestureRecognizer.setTranslation(.zero, in: entityView)
        case .ended:
            break
        default:
            break
        }
    }
    
    override func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingSimpleShapeEntity else {
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
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingSimpleShapeEntity else {
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
        var inset = self.selectionInset
        if let entityView = self.entityView as? DrawingSimpleShapeEntityView, let entity = entityView.entity as? DrawingSimpleShapeEntity, case .star = entity.shapeType {
            inset -= entityView.visualLineWidth / 2.0
        }
        
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
            self.bottomRightHandle
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
    }
    
    var isTracking: Bool {
        return gestureIsTracking(self.panGestureRecognizer)
    }
}
