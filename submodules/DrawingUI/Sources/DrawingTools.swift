import Foundation
import UIKit
import Display

protocol DrawingRenderLayer: CALayer {
    
}

final class MarkerTool: DrawingElement {
    let uuid = UUID()
    
    let drawingSize: CGSize
    let color: DrawingColor
    let lineWidth: CGFloat
    let arrow: Bool
    
    let renderLineWidth: CGFloat
    var renderPath = UIBezierPath()
    var renderAngle: CGFloat = 0.0
    
    var translation = CGPoint()
    
    var bounds: CGRect {
        return self.renderPath.bounds.offsetBy(dx: self.translation.x, dy: self.translation.y)
    }
    
    var _points: [Polyline.Point] = []
    var points: [Polyline.Point] {
        return self._points.map { $0.offsetBy(self.translation) }
    }

    weak var metalView: DrawingMetalView?
    
    func containsPoint(_ point: CGPoint) -> Bool {
        return self.renderPath.contains(point.offsetBy(CGPoint(x: -self.translation.x, y: -self.translation.y)))
    }
    
    func hasPointsInsidePath(_ path: UIBezierPath) -> Bool {
        let pathBoundingBox = path.bounds
        if self.bounds.intersects(pathBoundingBox) {
            for point in self._points {
                if path.contains(point.location.offsetBy(self.translation)) {
                    return true
                }
            }
        }
        return false
    }
    
    required init(drawingSize: CGSize, color: DrawingColor, lineWidth: CGFloat, arrow: Bool) {
        self.drawingSize = drawingSize
        self.color = color
        self.lineWidth = lineWidth
        self.arrow = arrow
                
        let minLineWidth = max(10.0, max(drawingSize.width, drawingSize.height) * 0.01)
        let maxLineWidth = max(20.0, max(drawingSize.width, drawingSize.height) * 0.09)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        self.renderLineWidth = lineWidth
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        return nil
    }
    
    private var hot = false
    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
        guard case let .location(point) = path else {
            return
        }
             
        if self._points.isEmpty {
            self.renderPath.move(to: point.location)
        } else {
            self.renderPath.addLine(to: point.location)
        }
        self._points.append(point)
        
        self.hot = true
        self.metalView?.updated(point, state: state, brush: .marker, color: self.color, size: self.renderLineWidth)
    }
    
    func draw(in context: CGContext, size: CGSize) {
        guard !self._points.isEmpty else {
            return
        }
        context.saveGState()
        
        context.translateBy(x: self.translation.x, y: self.translation.y)
        
        let hot = self.hot
        if hot {
            self.hot = false
        } else {
            self.metalView?.setup(self._points.map { $0.location }, brush: .marker, color: self.color, size: self.renderLineWidth)
        }
        self.metalView?.drawInContext(context)
        if !hot {
            self.metalView?.clear()
        }
        
        context.restoreGState()
    }
}
    
final class NeonTool: DrawingElement {
    class RenderLayer: SimpleLayer, DrawingRenderLayer {
        var lineWidth: CGFloat = 0.0
        
        let shadowLayer = SimpleShapeLayer()
        let borderLayer = SimpleShapeLayer()
        let fillLayer = SimpleShapeLayer()
        
        func setup(size: CGSize, color: DrawingColor, lineWidth: CGFloat, strokeWidth: CGFloat, shadowRadius: CGFloat) {
            self.contentsScale = 1.0
            self.lineWidth = lineWidth
                        
            let bounds = CGRect(origin: .zero, size: size)
            self.frame = bounds
            
            self.shadowLayer.frame = bounds
            self.shadowLayer.backgroundColor = UIColor.clear.cgColor
            self.shadowLayer.contentsScale = 1.0
            self.shadowLayer.lineWidth = strokeWidth * 0.5
            self.shadowLayer.lineCap = .round
            self.shadowLayer.lineJoin = .round
            self.shadowLayer.fillColor = UIColor.white.cgColor
            self.shadowLayer.strokeColor = UIColor.white.cgColor
            self.shadowLayer.shadowColor = color.toCGColor()
            self.shadowLayer.shadowRadius = shadowRadius
            self.shadowLayer.shadowOpacity = 1.0
            self.shadowLayer.shadowOffset = .zero

          
            self.borderLayer.frame = bounds
            self.borderLayer.contentsScale = 1.0
            self.borderLayer.lineWidth = strokeWidth
            self.borderLayer.lineCap = .round
            self.borderLayer.lineJoin = .round
            self.borderLayer.fillColor = UIColor.clear.cgColor
            self.borderLayer.strokeColor = UIColor.white.mixedWith(color.toUIColor(), alpha: 0.25).cgColor
            
          
            self.fillLayer.frame = bounds
            self.fillLayer.contentsScale = 1.0
            self.fillLayer.fillColor = UIColor.white.cgColor
            
            self.addSublayer(self.shadowLayer)
            self.addSublayer(self.borderLayer)
            self.addSublayer(self.fillLayer)
        }
        
        func updatePath(_ path: CGPath) {
            self.shadowLayer.path = path
            self.borderLayer.path = path
            self.fillLayer.path = path
        }
    }
    
    let uuid = UUID()
    
    let drawingSize: CGSize
    let color: DrawingColor
    let lineWidth: CGFloat
    let arrow: Bool
    
    var path: BezierPath?
    var boundingBox: CGRect?
    
    var renderPath: CGPath?
    let renderStrokeWidth: CGFloat
    let renderShadowRadius: CGFloat
    let renderLineWidth: CGFloat
    
    var translation = CGPoint()
    
    private var currentRenderLayer: DrawingRenderLayer?
    
    var bounds: CGRect {
        return self.path?.path.bounds.offsetBy(dx: self.translation.x, dy: self.translation.y) ?? .zero
    }
    
    var points: [Polyline.Point] {
        guard let linePath = self.path else {
            return []
        }
        var points: [Polyline.Point] = []
        for element in linePath.elements {
            if case .moveTo = element.type {
                points.append(element.startPoint.offsetBy(self.translation))
            } else {
                points.append(element.endPoint.offsetBy(self.translation))
            }
        }
        return points
    }
    
    func containsPoint(_ point: CGPoint) -> Bool {
        return self.renderPath?.contains(point.offsetBy(CGPoint(x: -self.translation.x, y: -self.translation.y))) ?? false
    }
    
    func hasPointsInsidePath(_ path: UIBezierPath) -> Bool {
        if let linePath = self.path {
            let pathBoundingBox = path.bounds
            if self.bounds.intersects(pathBoundingBox) {
                for element in linePath.elements {
                    if case .moveTo = element.type {
                        if path.contains(element.startPoint.location.offsetBy(self.translation)) {
                            return true
                        }
                    } else {
                        if path.contains(element.startPoint.location.offsetBy(self.translation)) {
                            return true
                        }
                        if path.contains(element.endPoint.location.offsetBy(self.translation)) {
                            return true
                        }
                        if case .cubicCurve = element.type {
                            if path.contains(element.controlPoints[0].offsetBy(self.translation)) {
                                return true
                            }
                            if path.contains(element.controlPoints[1].offsetBy(self.translation)) {
                                return true
                            }
                        } else if case .quadCurve = element.type {
                            if path.contains(element.controlPoints[0].offsetBy(self.translation)) {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }
    
    required init(drawingSize: CGSize, color: DrawingColor, lineWidth: CGFloat, arrow: Bool) {
        self.drawingSize = drawingSize
        self.color = color
        self.lineWidth = lineWidth
        self.arrow = arrow
        
        let strokeWidth = min(drawingSize.width, drawingSize.height) * 0.008
        let shadowRadius = min(drawingSize.width, drawingSize.height) * 0.03
        
        let minLineWidth = max(1.0, max(drawingSize.width, drawingSize.height) * 0.003)
        let maxLineWidth = max(10.0, max(drawingSize.width, drawingSize.height) * 0.09)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        self.renderStrokeWidth = strokeWidth
        self.renderShadowRadius = shadowRadius
        self.renderLineWidth = lineWidth
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        let layer = RenderLayer()
        layer.setup(size: self.drawingSize, color: self.color, lineWidth: self.renderLineWidth, strokeWidth: self.renderStrokeWidth, shadowRadius: self.renderShadowRadius)
        self.currentRenderLayer = layer
        return layer
    }
    
    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
        guard case let .smoothCurve(bezierPath) = path else {
            return
        }
        
        self.path = bezierPath

//        if self.arrow && polyline.isComplete, polyline.points.count > 2 {
//            let lastPoint = lastPosition
//            var secondPoint = polyline.points[polyline.points.count - 2]
//            if secondPoint.location.distance(to: lastPoint) < self.renderArrowLineWidth {
//                secondPoint = polyline.points[polyline.points.count - 3]
//            }
//            let angle = lastPoint.angle(to: secondPoint.location)
//            let point1 = lastPoint.pointAt(distance: self.renderArrowLength, angle: angle - CGFloat.pi * 0.15)
//            let point2 = lastPoint.pointAt(distance: self.renderArrowLength, angle: angle + CGFloat.pi * 0.15)
//            
//            let arrowPath = UIBezierPath()
//            arrowPath.move(to: point2)
//            arrowPath.addLine(to: lastPoint)
//            arrowPath.addLine(to: point1)
//            let arrowThickPath = arrowPath.cgPath.copy(strokingWithWidth: self.renderArrowLineWidth, lineCap: .round, lineJoin: .round, miterLimit: 0.0)
//            
//            combinedPath.usesEvenOddFillRule = false
//            combinedPath.append(UIBezierPath(cgPath: arrowThickPath))
//        }
        
        
        let cgPath = bezierPath.path.cgPath.copy(strokingWithWidth: self.renderLineWidth, lineCap: .round, lineJoin: .round, miterLimit: 0.0)
        self.renderPath = cgPath
        
        if let currentRenderLayer = self.currentRenderLayer as? RenderLayer {
            currentRenderLayer.updatePath(cgPath)
        }
    }

    func draw(in context: CGContext, size: CGSize) {
        guard let path = self.renderPath else {
            return
        }
        context.saveGState()
        
        context.translateBy(x: self.translation.x, y: self.translation.y)
        
        context.setShouldAntialias(true)

        context.setBlendMode(.normal)

        context.addPath(path)
        context.setFillColor(UIColor.white.cgColor)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(self.renderStrokeWidth * 0.5)
        context.setShadow(offset: .zero, blur: self.renderShadowRadius * 1.9, color: self.color.toCGColor())
        context.drawPath(using: .fillStroke)

        context.addPath(path)
        context.setShadow(offset: .zero, blur: 0.0, color: UIColor.clear.cgColor)
        context.setLineCap(.round)
        context.setLineWidth(self.renderStrokeWidth)
        context.setStrokeColor(UIColor.white.mixedWith(self.color.toUIColor(), alpha: 0.25).cgColor)
        context.strokePath()

        context.addPath(path)
        context.setFillColor(UIColor.white.cgColor)

        context.fillPath()
        
        context.restoreGState()
    }
}

final class PencilTool: DrawingElement {
    let uuid = UUID()
    
    let drawingSize: CGSize
    let color: DrawingColor
    let lineWidth: CGFloat
    let arrow: Bool
    
    var translation = CGPoint()
    
    let renderLineWidth: CGFloat
    var renderPath = UIBezierPath()
    var renderAngle: CGFloat = 0.0
    
    var bounds: CGRect {
        return self.renderPath.bounds.offsetBy(dx: self.translation.x, dy: self.translation.y)
    }
    
    var _points: [Polyline.Point] = []
    var points: [Polyline.Point] {
        return self._points.map { $0.offsetBy(self.translation) }
    }
    
    weak var metalView: DrawingMetalView?
    
    func containsPoint(_ point: CGPoint) -> Bool {
        return self.renderPath.contains(point.offsetBy(dx: -self.translation.x, dy: -self.translation.y))
    }
    
    func hasPointsInsidePath(_ path: UIBezierPath) -> Bool {
        let pathBoundingBox = path.bounds
        if self.bounds.intersects(pathBoundingBox) {
            for point in self._points {
                if path.contains(point.location.offsetBy(self.translation)) {
                    return true
                }
            }
        }
        return false
    }
    
    required init(drawingSize: CGSize, color: DrawingColor, lineWidth: CGFloat, arrow: Bool) {
        self.drawingSize = drawingSize
        self.color = color
        self.lineWidth = lineWidth
        self.arrow = arrow
                
        let minLineWidth = max(10.0, max(drawingSize.width, drawingSize.height) * 0.01)
        let maxLineWidth = max(20.0, max(drawingSize.width, drawingSize.height) * 0.09)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        self.renderLineWidth = lineWidth
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        return nil
    }
    
    private var hot = false
    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
        guard case let .location(point) = path else {
            return
        }
        
        if self._points.isEmpty {
            self.renderPath.move(to: point.location)
        } else {
            self.renderPath.addLine(to: point.location)
        }
        self._points.append(point)
        
        self.hot = true
        self.metalView?.updated(point, state: state, brush: .pencil, color: self.color, size: self.renderLineWidth)
    }
    
    func draw(in context: CGContext, size: CGSize) {
        guard !self._points.isEmpty else {
            return
        }
        context.saveGState()
        
        context.translateBy(x: self.translation.x, y: self.translation.y)
        
        let hot = self.hot
        if hot {
            self.hot = false
        } else {
            self.metalView?.setup(self._points.map { $0.location }, brush: .pencil, color: self.color, size: self.renderLineWidth)
        }
        self.metalView?.drawInContext(context)
        if !hot {
            self.metalView?.clear()
        }
        
        context.restoreGState()
    }
}

final class FillTool: DrawingElement {
    let uuid = UUID()

    let drawingSize: CGSize
    let color: DrawingColor
    let renderLineWidth: CGFloat = 0.0
    
    var bounds: CGRect {
        return .zero
    }
    
    var points: [Polyline.Point] {
        return []
    }
    
    var translation = CGPoint()
    
    required init(drawingSize: CGSize, color: DrawingColor, lineWidth: CGFloat, arrow: Bool) {
        self.drawingSize = drawingSize
        self.color = color
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        return nil
    }
    
    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
    }

    func draw(in context: CGContext, size: CGSize) {
        context.setShouldAntialias(false)

        context.setBlendMode(.copy)

        context.setFillColor(self.color.toCGColor())
        context.fill(CGRect(origin: .zero, size: size))

        context.setBlendMode(.normal)
    }
    
    func containsPoint(_ point: CGPoint) -> Bool {
        return false
    }
    
    func hasPointsInsidePath(_ path: UIBezierPath) -> Bool {
        return false
    }
}


final class BlurTool: DrawingElement {
    class RenderLayer: SimpleLayer, DrawingRenderLayer {
        var lineWidth: CGFloat = 0.0
        
        let blurLayer = SimpleLayer()
        let fillLayer = SimpleShapeLayer()
        
        func setup(size: CGSize, color: DrawingColor, lineWidth: CGFloat, image: UIImage?) {
            self.contentsScale = 1.0
            self.lineWidth = lineWidth
                        
            let bounds = CGRect(origin: .zero, size: size)
            self.frame = bounds
            
            self.blurLayer.frame = bounds
            self.fillLayer.frame = bounds
            
            if self.blurLayer.contents == nil, let image = image {
                self.blurLayer.contents = image.cgImage
            }
            self.blurLayer.mask = self.fillLayer
          
            self.fillLayer.frame = bounds
            self.fillLayer.contentsScale = 1.0
            self.fillLayer.strokeColor = UIColor.white.cgColor
            self.fillLayer.fillColor = UIColor.clear.cgColor
            self.fillLayer.lineCap = .round
            self.fillLayer.lineWidth = lineWidth
            
            self.addSublayer(self.blurLayer)
        }
        
        func updatePath(_ path: CGPath) {
            self.fillLayer.path = path
        }
    }
    
    var getFullImage: () -> UIImage? = { return nil }
    
    let uuid = UUID()
    
    let drawingSize: CGSize
    let color: DrawingColor
    let lineWidth: CGFloat
    let arrow: Bool
    
    var path: BezierPath?
    var boundingBox: CGRect?
    
    var renderPath: CGPath?
    let renderLineWidth: CGFloat
    
    var translation = CGPoint()
    
    private var currentRenderLayer: DrawingRenderLayer?
    
    var bounds: CGRect {
        return self.path?.path.bounds.offsetBy(dx: self.translation.x, dy: self.translation.y) ?? .zero
    }
    
    var points: [Polyline.Point] {
        guard let linePath = self.path else {
            return []
        }
        var points: [Polyline.Point] = []
        for element in linePath.elements {
            if case .moveTo = element.type {
                points.append(element.startPoint.offsetBy(self.translation))
            } else {
                points.append(element.endPoint.offsetBy(self.translation))
            }
        }
        return points
    }
    
    func containsPoint(_ point: CGPoint) -> Bool {
        return self.renderPath?.contains(point.offsetBy(CGPoint(x: -self.translation.x, y: -self.translation.y))) ?? false
    }
    
    func hasPointsInsidePath(_ path: UIBezierPath) -> Bool {
        if let linePath = self.path {
            let pathBoundingBox = path.bounds
            if self.bounds.intersects(pathBoundingBox) {
                for element in linePath.elements {
                    if case .moveTo = element.type {
                        if path.contains(element.startPoint.location.offsetBy(self.translation)) {
                            return true
                        }
                    } else {
                        if path.contains(element.startPoint.location.offsetBy(self.translation)) {
                            return true
                        }
                        if path.contains(element.endPoint.location.offsetBy(self.translation)) {
                            return true
                        }
                        if case .cubicCurve = element.type {
                            if path.contains(element.controlPoints[0].offsetBy(self.translation)) {
                                return true
                            }
                            if path.contains(element.controlPoints[1].offsetBy(self.translation)) {
                                return true
                            }
                        } else if case .quadCurve = element.type {
                            if path.contains(element.controlPoints[0].offsetBy(self.translation)) {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }
    
    required init(drawingSize: CGSize, color: DrawingColor, lineWidth: CGFloat, arrow: Bool) {
        self.drawingSize = drawingSize
        self.color = color
        self.lineWidth = lineWidth
        self.arrow = arrow
            
        let minLineWidth = max(1.0, max(drawingSize.width, drawingSize.height) * 0.003)
        let maxLineWidth = max(10.0, max(drawingSize.width, drawingSize.height) * 0.09)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        self.renderLineWidth = lineWidth
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        let layer = RenderLayer()
        layer.setup(size: self.drawingSize, color: self.color, lineWidth: self.renderLineWidth, image: self.getFullImage())
        self.currentRenderLayer = layer
        return layer
    }
    
    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
        guard case let .smoothCurve(bezierPath) = path else {
            return
        }
        
        self.path = bezierPath
        
        let renderPath = bezierPath.path.cgPath
        self.renderPath = renderPath
        
        if let currentRenderLayer = self.currentRenderLayer as? RenderLayer {
            currentRenderLayer.updatePath(renderPath)
        }
    }

    func draw(in context: CGContext, size: CGSize) {
        context.translateBy(x: self.translation.x, y: self.translation.y)
        
        let renderLayer: DrawingRenderLayer?
        if let currentRenderLayer = self.currentRenderLayer {
            renderLayer = currentRenderLayer
        } else {
            renderLayer = self.setupRenderLayer()
        }
        renderLayer?.render(in: context)
    }
}


final class EraserTool: DrawingElement {
    class RenderLayer: SimpleLayer, DrawingRenderLayer {
        var lineWidth: CGFloat = 0.0
        
        let blurLayer = SimpleLayer()
        let fillLayer = SimpleShapeLayer()
        
        func setup(size: CGSize, color: DrawingColor, lineWidth: CGFloat, image: UIImage?) {
            self.contentsScale = 1.0
            self.lineWidth = lineWidth
                        
            let bounds = CGRect(origin: .zero, size: size)
            self.frame = bounds
            
            self.blurLayer.frame = bounds
            self.fillLayer.frame = bounds
            
            if self.blurLayer.contents == nil, let image = image {
                self.blurLayer.contents = image.cgImage
                self.blurLayer.contentsGravity = .resize
            }
            self.blurLayer.mask = self.fillLayer
          
            self.fillLayer.frame = bounds
            self.fillLayer.contentsScale = 1.0
            self.fillLayer.strokeColor = UIColor.white.cgColor
            self.fillLayer.fillColor = UIColor.clear.cgColor
            self.fillLayer.lineCap = .round
            self.fillLayer.lineWidth = lineWidth
            
            self.addSublayer(self.blurLayer)
        }
        
        func updatePath(_ path: CGPath) {
            self.fillLayer.path = path
        }
    }
    
    var getFullImage: () -> UIImage? = { return nil }
    
    let uuid = UUID()
    
    let drawingSize: CGSize
    let color: DrawingColor
    let lineWidth: CGFloat
    let arrow: Bool
    
    var path: BezierPath?
    var boundingBox: CGRect?
    
    var renderPath: CGPath?
    let renderLineWidth: CGFloat
    
    var translation = CGPoint()
    
    private var currentRenderLayer: DrawingRenderLayer?
    
    var bounds: CGRect {
        return self.path?.path.bounds.offsetBy(dx: self.translation.x, dy: self.translation.y) ?? .zero
    }
    
    var points: [Polyline.Point] {
        guard let linePath = self.path else {
            return []
        }
        var points: [Polyline.Point] = []
        for element in linePath.elements {
            if case .moveTo = element.type {
                points.append(element.startPoint.offsetBy(self.translation))
            } else {
                points.append(element.endPoint.offsetBy(self.translation))
            }
        }
        return points
    }
    
    func containsPoint(_ point: CGPoint) -> Bool {
        return false
//        return self.renderPath?.contains(point.offsetBy(CGPoint(x: -self.translation.x, y: -self.translation.y))) ?? false
    }
    
    func hasPointsInsidePath(_ path: UIBezierPath) -> Bool {
        if let linePath = self.path {
            let pathBoundingBox = path.bounds
            if self.bounds.intersects(pathBoundingBox) {
                for element in linePath.elements {
                    if case .moveTo = element.type {
                        if path.contains(element.startPoint.location.offsetBy(self.translation)) {
                            return true
                        }
                    } else {
                        if path.contains(element.startPoint.location.offsetBy(self.translation)) {
                            return true
                        }
                        if path.contains(element.endPoint.location.offsetBy(self.translation)) {
                            return true
                        }
                        if case .cubicCurve = element.type {
                            if path.contains(element.controlPoints[0].offsetBy(self.translation)) {
                                return true
                            }
                            if path.contains(element.controlPoints[1].offsetBy(self.translation)) {
                                return true
                            }
                        } else if case .quadCurve = element.type {
                            if path.contains(element.controlPoints[0].offsetBy(self.translation)) {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }
    
    required init(drawingSize: CGSize, color: DrawingColor, lineWidth: CGFloat, arrow: Bool) {
        self.drawingSize = drawingSize
        self.color = color
        self.lineWidth = lineWidth
        self.arrow = arrow
            
        let minLineWidth = max(1.0, max(drawingSize.width, drawingSize.height) * 0.003)
        let maxLineWidth = max(10.0, max(drawingSize.width, drawingSize.height) * 0.09)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        self.renderLineWidth = lineWidth
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        let layer = RenderLayer()
        layer.setup(size: self.drawingSize, color: self.color, lineWidth: self.renderLineWidth, image: self.getFullImage())
        self.currentRenderLayer = layer
        return layer
    }
    
    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
        guard case let .smoothCurve(bezierPath) = path else {
            return
        }
        
        self.path = bezierPath
        
        let renderPath = bezierPath.path.cgPath
        self.renderPath = renderPath
        
        if let currentRenderLayer = self.currentRenderLayer as? RenderLayer {
            currentRenderLayer.updatePath(renderPath)
        }
    }

    func draw(in context: CGContext, size: CGSize) {
        context.translateBy(x: self.translation.x, y: self.translation.y)
        
        let renderLayer: DrawingRenderLayer?
        if let currentRenderLayer = self.currentRenderLayer {
            renderLayer = currentRenderLayer
        } else {
            renderLayer = self.setupRenderLayer()
        }
        renderLayer?.render(in: context)
    }
}
