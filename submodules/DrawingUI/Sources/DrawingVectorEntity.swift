import Foundation
import UIKit
import Display
import AccountContext
import MediaEditor

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
    
    override func animateSelection() {
        guard let selectionView = self.selectionView else {
            return
        }
                
        selectionView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: 0.1)
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
            mid: self.midPoint,
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
                    mid: self.midPoint,
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
        
    override func makeSelectionView() -> DrawingEntitySelectionView? {
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
    
    var _cachedMidPoint: (start: CGPoint, end: CGPoint, midLength: CGFloat, midHeight: CGFloat, midPoint: CGPoint)?
    var midPoint: CGPoint {
        let entity = self.vectorEntity
        if let (start, end, midLength, midHeight, midPoint) = self._cachedMidPoint, start == entity.start, end == entity.end, midLength == entity.mid.0, midHeight == entity.mid.1 {
            return midPoint
        } else {
            let midPoint = midPointPositionFor(start: entity.start, end: entity.end, length: entity.mid.0, height: entity.mid.1)
            self._cachedMidPoint = (entity.start, entity.end, entity.mid.0, entity.mid.1, midPoint)
            return midPoint
        }
    }
}

private func midPointPositionFor(start: CGPoint, end: CGPoint, length: CGFloat, height: CGFloat) -> CGPoint {
    let distance = end.distance(to: start)
    let angle = start.angle(to: end)
    let p1 = start.pointAt(distance: distance * length, angle: angle)
    let p2 = p1.pointAt(distance: distance * height, angle: angle + .pi * 0.5)
    return p2
}

final class DrawingVectorEntititySelectionView: DrawingEntitySelectionView {
    private let startHandle = SimpleShapeLayer()
    private let midHandle = SimpleShapeLayer()
    private let endHandle = SimpleShapeLayer()
  
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var currentHandle: CALayer?
    override func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let entityView = self.entityView as? DrawingVectorEntityView, let entity = entityView.entity as? DrawingVectorEntity else {
            return
        }
        let location = gestureRecognizer.location(in: self)
        
        switch gestureRecognizer.state {
        case .began:
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
        case .changed:
            if self.currentHandle == nil {
                self.currentHandle = self.layer
            }
            
            if gestureRecognizer.numberOfTouches > 1 {
                return
            }
            
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
                var updatedMidPoint = entityView.midPoint
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
            entityView.update(animated: false)
            
            gestureRecognizer.setTranslation(.zero, in: entityView)
        case .ended, .cancelled:
            entityView.onInteractionUpdated(false)
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
        self.midHandle.position = entityView.midPoint
        self.midHandle.bounds = bounds
        self.midHandle.lineWidth = lineWidth
        
        self.endHandle.path = handlePath
        self.endHandle.position = entity.end
        self.endHandle.bounds = bounds
        self.endHandle.lineWidth = lineWidth
    }
}
