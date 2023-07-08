import Foundation
import UIKit
import Display
import AccountContext
import MediaEditor

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
        
        guard let selectionView = self.selectionView as? DrawingBubbleEntitySelectionView else {
            return
        }
        
        selectionView.transform = CGAffineTransformMakeRotation(self.bubbleEntity.rotation)
        selectionView.setNeedsLayout()
    }
        
    override func makeSelectionView() -> DrawingEntitySelectionView? {
        if let selectionView = self.selectionView {
            return selectionView
        }
        let selectionView = DrawingBubbleEntitySelectionView()
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

final class DrawingBubbleEntitySelectionView: DrawingEntitySelectionView {
    private let leftHandle = SimpleShapeLayer()
    private let topLeftHandle = SimpleShapeLayer()
    private let topHandle = SimpleShapeLayer()
    private let topRightHandle = SimpleShapeLayer()
    private let rightHandle = SimpleShapeLayer()
    private let bottomLeftHandle = SimpleShapeLayer()
    private let bottomHandle = SimpleShapeLayer()
    private let bottomRightHandle = SimpleShapeLayer()
    private let tailHandle = SimpleShapeLayer()
      
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
            var updatedTailPosition = entity.tailPosition
            
            let minimumSize = entityView.minimumSize
            
            if self.currentHandle != nil && self.currentHandle !== self.layer {
                if gestureRecognizer.numberOfTouches > 1 {
                    return
                }
            }
            
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
                
                updatedPosition = self.snapTool.update(entityView: entityView, velocity: velocity, delta: delta, updatedPosition: updatedPosition, size: entityView.frame.size)
            }
            
            entity.size = updatedSize
            entity.position = updatedPosition
            entity.tailPosition = updatedTailPosition
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
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingBubbleEntity else {
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
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingBubbleEntity else {
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
            entityView.onInteractionUpdated(false)
            self.snapTool.rotationReset()
        default:
            break
        }
                
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
}
