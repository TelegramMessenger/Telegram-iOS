import Foundation
import UIKit
import Display
import AccountContext
import MediaEditor

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
            
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: maxLineWidth * 0.5, dy: maxLineWidth * 0.5)
            switch shapeType {
            case .rectangle:
                self.shapeLayer.path = CGPath(rect: rect, transform: nil)
            case .ellipse:
                self.shapeLayer.path = CGPath(ellipseIn: rect, transform: nil)
            case .star:
                self.shapeLayer.path = CGPath.star(in: rect, extrusion: size.width * 0.2, points: 5)
            }
        }
        
        switch self.shapeEntity.drawType {
        case .fill:
            self.shapeLayer.fillColor = self.shapeEntity.color.toCGColor()
            self.shapeLayer.strokeColor = UIColor.clear.cgColor
        case .stroke:
            let minLineWidth = max(10.0, max(self.shapeEntity.referenceDrawingSize.width, self.shapeEntity.referenceDrawingSize.height) * 0.01)
            let maxLineWidth = self.maxLineWidth
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
    
    fileprivate var maxLineWidth: CGFloat {
        return max(10.0, max(self.shapeEntity.referenceDrawingSize.width, self.shapeEntity.referenceDrawingSize.height) * 0.05)
    }
    
    fileprivate var minimumSize: CGSize {
        let minSize = min(self.shapeEntity.referenceDrawingSize.width, self.shapeEntity.referenceDrawingSize.height)
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
        if case .stroke = self.shapeEntity.drawType, var path = self.shapeLayer.path {
            path = path.copy(strokingWithWidth: self.maxLineWidth * 0.8, lineCap: .square, lineJoin: .bevel, miterLimit: 0.0)
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
        
    override func makeSelectionView() -> DrawingEntitySelectionView? {
        if let selectionView = self.selectionView {
            return selectionView
        }
        let selectionView = DrawingSimpleShapeEntititySelectionView()
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
    
    override var selectionBounds: CGRect {
        return self.bounds.insetBy(dx: self.maxLineWidth * 0.5, dy: self.maxLineWidth * 0.5)
    }
}

final class DrawingSimpleShapeEntititySelectionView: DrawingEntitySelectionView {
    private let leftHandle = SimpleShapeLayer()
    private let topLeftHandle = SimpleShapeLayer()
    private let topHandle = SimpleShapeLayer()
    private let topRightHandle = SimpleShapeLayer()
    private let rightHandle = SimpleShapeLayer()
    private let bottomLeftHandle = SimpleShapeLayer()
    private let bottomHandle = SimpleShapeLayer()
    private let bottomRightHandle = SimpleShapeLayer()
    

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
        return 5.5
    }
        
    private let snapTool = DrawingEntitySnapTool()
    
    private var currentHandle: CALayer?
    override func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let entityView = self.entityView as? DrawingSimpleShapeEntityView, let entity = entityView.entity as? DrawingSimpleShapeEntity else {
            return
        }
        let isAspectLocked = [.star].contains(entity.shapeType)
        let location = gestureRecognizer.location(in: self)
        
        switch gestureRecognizer.state {
        case .began:
            self.snapTool.maybeSkipFromStart(entityView: entityView, position: entity.position)
            
            if let sublayers = self.layer.sublayers {
                for layer in sublayers {
                    if layer.frame.contains(location) {
                        self.currentHandle = layer
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
            let velocity = gestureRecognizer.velocity(in: entityView.superview)
            
            var updatedSize = entity.size
            var updatedPosition = entity.position
            
            let minimumSize = entityView.minimumSize
            
            if self.currentHandle != nil && self.currentHandle !== self.layer {
                if gestureRecognizer.numberOfTouches > 1 {
                    return
                }
            }
            
            if self.currentHandle === self.leftHandle {
                let deltaX = delta.x * cos(entity.rotation)
                let deltaY = delta.x * sin(entity.rotation)
                                
                updatedSize.width = max(minimumSize.width, updatedSize.width - deltaX)
                updatedPosition.x -= deltaX * -0.5
                updatedPosition.y -= deltaY * -0.5
                
                if isAspectLocked {
                    updatedSize.height = updatedSize.width
                }
            } else if self.currentHandle === self.rightHandle {
                let deltaX = delta.x * cos(entity.rotation)
                let deltaY = delta.x * sin(entity.rotation)
                
                updatedSize.width = max(minimumSize.width, updatedSize.width + deltaX)
                print(updatedSize.width)
                updatedPosition.x += deltaX * 0.5
                updatedPosition.y += deltaY * 0.5
                if isAspectLocked {
                    updatedSize.height = updatedSize.width
                }
            } else if self.currentHandle === self.topHandle {
                let deltaX = delta.y * sin(entity.rotation)
                let deltaY = delta.y * cos(entity.rotation)
                
                updatedSize.height = max(minimumSize.height, updatedSize.height - deltaY)
                updatedPosition.x += deltaX * 0.5
                updatedPosition.y += deltaY * 0.5
                if isAspectLocked {
                    updatedSize.width = updatedSize.height
                }
            } else if self.currentHandle === self.bottomHandle {
                let deltaX = delta.y * sin(entity.rotation)
                let deltaY = delta.y * cos(entity.rotation)
                
                updatedSize.height = max(minimumSize.height, updatedSize.height + deltaY)
                updatedPosition.x += deltaX * 0.5
                updatedPosition.y += deltaY * 0.5
                if isAspectLocked {
                    updatedSize.width = updatedSize.height
                }
            } else if self.currentHandle === self.topLeftHandle {
                var delta = delta
                if isAspectLocked {
                    delta = CGPoint(x: delta.x, y: delta.x)
                }
                
                updatedSize.width = max(minimumSize.width, updatedSize.width - delta.x)
                updatedPosition.x -= delta.x * -0.5
                updatedSize.height =  max(minimumSize.height, updatedSize.height - delta.y)
                updatedPosition.y += delta.y * 0.5
            } else if self.currentHandle === self.topRightHandle {
                var delta = delta
                if isAspectLocked {
                    delta = CGPoint(x: delta.x, y: -delta.x)
                }
                updatedSize.width = max(minimumSize.width, updatedSize.width + delta.x)
                updatedPosition.x += delta.x * 0.5
                updatedSize.height =  max(minimumSize.height, updatedSize.height - delta.y)
                updatedPosition.y += delta.y * 0.5
            } else if self.currentHandle === self.bottomLeftHandle {
                var delta = delta
                if isAspectLocked {
                    delta = CGPoint(x: delta.x, y: -delta.x)
                }
                updatedSize.width = max(minimumSize.width, updatedSize.width - delta.x)
                updatedPosition.x -= delta.x * -0.5
                updatedSize.height = max(minimumSize.height, updatedSize.height + delta.y)
                updatedPosition.y += delta.y * 0.5
            } else if self.currentHandle === self.bottomRightHandle {
                var delta = delta
                if isAspectLocked {
                    delta = CGPoint(x: delta.x, y: delta.x)
                }
                updatedSize.width = max(minimumSize.width, updatedSize.width + delta.x)
                updatedPosition.x += delta.x * 0.5
                updatedSize.height = max(minimumSize.height, updatedSize.height + delta.y)
                updatedPosition.y += delta.y * 0.5
            } else if self.currentHandle === self.layer {
                updatedPosition.x += delta.x
                updatedPosition.y += delta.y
                
                updatedPosition = self.snapTool.update(entityView: entityView, velocity: velocity, delta: delta, updatedPosition: updatedPosition, size: entityView.frame.size)
            }
            
            entity.size = updatedSize
            entity.position = updatedPosition
            entityView.update(animated: false)
            
            gestureRecognizer.setTranslation(.zero, in: entityView)
        case .ended, .cancelled:
            self.snapTool.reset()
            entityView.onInteractionUpdated(false)
        default:
            break
        }
        
        entityView.onPositionUpdated(entity.position)
    }
    
    override func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingSimpleShapeEntity else {
            return
        }
        
        switch gestureRecognizer.state {
        case .began, .changed:
            if case .began = gestureRecognizer.state {
                entityView.onInteractionUpdated(true)
            }
            let scale = gestureRecognizer.scale
            entity.size = CGSize(width: entity.size.width * scale, height: entity.size.height * scale)
            entityView.update()
            
            gestureRecognizer.scale = 1.0
        case .ended, .cancelled:
            entityView.onInteractionUpdated(false)
        default:
            break
        }
    }
    
    override func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingSimpleShapeEntity else {
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
}
