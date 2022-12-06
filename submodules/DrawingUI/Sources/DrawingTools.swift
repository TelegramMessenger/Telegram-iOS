import Foundation
import UIKit
import Display

protocol DrawingRenderLayer: CALayer {
    
}

//final class PenTool: DrawingElement {
//    class RenderLayer: SimpleLayer, DrawingRenderLayer {
//        var lineWidth: CGFloat = 0.0
//                
//        func setup(size: CGSize, color: DrawingColor, lineWidth: CGFloat, strokeWidth: CGFloat, shadowRadius: CGFloat) {
//            self.contentsScale = 1.0
//            self.lineWidth = lineWidth
//                        
//
//        }
//    }
//    
//    let uuid = UUID()
//    
//    let drawingSize: CGSize
//    let color: DrawingColor
//    let lineWidth: CGFloat
//    let arrow: Bool
//    
//    var path: BezierPath?
//    var boundingBox: CGRect?
//    
//    var renderPath: CGPath?
//    let renderStrokeWidth: CGFloat
//    let renderShadowRadius: CGFloat
//    let renderLineWidth: CGFloat
//    
//    var translation = CGPoint()
//    
//    private var currentRenderLayer: DrawingRenderLayer?
//    
//    var bounds: CGRect {
//        return self.path?.path.bounds.offsetBy(dx: self.translation.x, dy: self.translation.y) ?? .zero
//    }
//    
//    var points: [Polyline.Point] {
//        guard let linePath = self.path else {
//            return []
//        }
//        var points: [Polyline.Point] = []
//        for element in linePath.elements {
//            if case .moveTo = element.type {
//                points.append(element.startPoint.offsetBy(self.translation))
//            } else {
//                points.append(element.endPoint.offsetBy(self.translation))
//            }
//        }
//        return points
//    }
//    
//    func containsPoint(_ point: CGPoint) -> Bool {
//        return self.renderPath?.contains(point.offsetBy(CGPoint(x: -self.translation.x, y: -self.translation.y))) ?? false
//    }
//    
//    func hasPointsInsidePath(_ path: UIBezierPath) -> Bool {
//        if let linePath = self.path {
//            let pathBoundingBox = path.bounds
//            if self.bounds.intersects(pathBoundingBox) {
//                for element in linePath.elements {
//                    if case .moveTo = element.type {
//                        if path.contains(element.startPoint.location.offsetBy(self.translation)) {
//                            return true
//                        }
//                    } else {
//                        if path.contains(element.startPoint.location.offsetBy(self.translation)) {
//                            return true
//                        }
//                        if path.contains(element.endPoint.location.offsetBy(self.translation)) {
//                            return true
//                        }
//                        if case .cubicCurve = element.type {
//                            if path.contains(element.controlPoints[0].offsetBy(self.translation)) {
//                                return true
//                            }
//                            if path.contains(element.controlPoints[1].offsetBy(self.translation)) {
//                                return true
//                            }
//                        } else if case .quadCurve = element.type {
//                            if path.contains(element.controlPoints[0].offsetBy(self.translation)) {
//                                return true
//                            }
//                        }
//                    }
//                }
//            }
//        }
//        return false
//    }
//    
//    required init(drawingSize: CGSize, color: DrawingColor, lineWidth: CGFloat, arrow: Bool) {
//        self.drawingSize = drawingSize
//        self.color = color
//        self.lineWidth = lineWidth
//        self.arrow = arrow
//        
//        let strokeWidth = min(drawingSize.width, drawingSize.height) * 0.008
//        let shadowRadius = min(drawingSize.width, drawingSize.height) * 0.03
//        
//        let minLineWidth = max(1.0, min(drawingSize.width, drawingSize.height) * 0.003)
//        let maxLineWidth = max(10.0, min(drawingSize.width, drawingSize.height) * 0.09)
//        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
//        
//        self.renderStrokeWidth = strokeWidth
//        self.renderShadowRadius = shadowRadius
//        self.renderLineWidth = lineWidth
//    }
//    
//    func setupRenderLayer() -> DrawingRenderLayer? {
//        let layer = RenderLayer()
//        layer.setup(size: self.drawingSize, color: self.color, lineWidth: self.renderLineWidth, strokeWidth: self.renderStrokeWidth, shadowRadius: self.renderShadowRadius)
//        self.currentRenderLayer = layer
//        return layer
//    }
//    
//    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
//        guard case let .smoothCurve(bezierPath) = path else {
//            return
//        }
//        
//        self.path = bezierPath
//
////        if self.arrow && polyline.isComplete, polyline.points.count > 2 {
////            let lastPoint = lastPosition
////            var secondPoint = polyline.points[polyline.points.count - 2]
////            if secondPoint.location.distance(to: lastPoint) < self.renderArrowLineWidth {
////                secondPoint = polyline.points[polyline.points.count - 3]
////            }
////            let angle = lastPoint.angle(to: secondPoint.location)
////            let point1 = lastPoint.pointAt(distance: self.renderArrowLength, angle: angle - CGFloat.pi * 0.15)
////            let point2 = lastPoint.pointAt(distance: self.renderArrowLength, angle: angle + CGFloat.pi * 0.15)
////
////            let arrowPath = UIBezierPath()
////            arrowPath.move(to: point2)
////            arrowPath.addLine(to: lastPoint)
////            arrowPath.addLine(to: point1)
////            let arrowThickPath = arrowPath.cgPath.copy(strokingWithWidth: self.renderArrowLineWidth, lineCap: .round, lineJoin: .round, miterLimit: 0.0)
////
////            combinedPath.usesEvenOddFillRule = false
////            combinedPath.append(UIBezierPath(cgPath: arrowThickPath))
////        }
//        
//        
//        let cgPath = bezierPath.path.cgPath.copy(strokingWithWidth: self.renderLineWidth, lineCap: .round, lineJoin: .round, miterLimit: 0.0)
//        self.renderPath = cgPath
//        
//        if let currentRenderLayer = self.currentRenderLayer as? RenderLayer {
//            currentRenderLayer.updatePath(cgPath)
//        }
//    }
//
//    func draw(in context: CGContext, size: CGSize) {
//        guard let path = self.renderPath else {
//            return
//        }
//        context.saveGState()
//        
//        context.translateBy(x: self.translation.x, y: self.translation.y)
//        
//        context.setShouldAntialias(true)
//
//        context.setBlendMode(.normal)
//
//        context.addPath(path)
//        context.setFillColor(UIColor.white.cgColor)
//        context.setStrokeColor(UIColor.white.cgColor)
//        context.setLineWidth(self.renderStrokeWidth * 0.5)
//        context.setShadow(offset: .zero, blur: self.renderShadowRadius * 3.0, color: self.color.toCGColor())
//        context.drawPath(using: .fillStroke)
//
//        context.addPath(path)
//        context.setShadow(offset: .zero, blur: 0.0, color: UIColor.clear.cgColor)
//        context.setLineCap(.round)
//        context.setLineWidth(self.renderStrokeWidth)
//        context.setStrokeColor(UIColor.white.mixedWith(self.color.toUIColor(), alpha: 0.25).cgColor)
//        context.strokePath()
//
//        context.addPath(path)
//        context.setFillColor(UIColor.white.cgColor)
//
//        context.fillPath()
//        
//        context.restoreGState()
//    }
//}

//final class PenTool: DrawingElement {
//    class RenderLayer: SimpleLayer, DrawingRenderLayer {
//        var lineWidth: CGFloat = 0.0
//
//        let fillLayer = SimpleShapeLayer()
//
//        func setup(size: CGSize, color: DrawingColor, lineWidth: CGFloat) {
//            self.contentsScale = 1.0
//
//            let minLineWidth = max(1.0, min(size.width, size.height) * 0.003)
//            let maxLineWidth = max(10.0, min(size.width, size.height) * 0.055)
//            let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
//
//            self.lineWidth = lineWidth
//
//            let bounds = CGRect(origin: .zero, size: size)
//            self.frame = bounds
//
//            self.fillLayer.frame = bounds
//            self.fillLayer.contentsScale = 1.0
//            self.fillLayer.fillColor = color.toCGColor()
//            self.fillLayer.strokeColor = color.toCGColor()
//            self.fillLayer.lineWidth = 1.0
//
//            self.addSublayer(self.fillLayer)
//        }
//
//        func updatePath(_ path: CGPath) {
//            self.fillLayer.path = path
//        }
//    }
//
//    let uuid = UUID()
//
//    let drawingSize: CGSize
//    let color: DrawingColor
//    let lineWidth: CGFloat
//    let arrow: Bool
//
//    var polyline: Polyline?
////    var path = BezierPath()
//    let renderArrowLength: CGFloat
//    let renderArrowLineWidth: CGFloat
//    var renderLineWidth: CGFloat = 0.0
//
//    var translation = CGPoint()
//
//    private var currentRenderLayer: DrawingRenderLayer?
//
//    var bounds: CGRect {
//        return .zero
//    }
//
//    var points: [CGPoint] {
//        guard let polyline = self.polyline else {
//            return []
//        }
//        var points: [CGPoint] = []
//        for point in polyline.points {
//            points.append(point.location)
//        }
//        return points
//    }
//
//    func containsPoint(_ point: CGPoint) -> Bool {
//        return false
//    }
//
//    func hasPointsInsidePath(_ path: UIBezierPath) -> Bool {
//        if let polyline = self.polyline {
//            let pathBoundingBox = path.bounds
//            if self.bounds.intersects(pathBoundingBox) {
//                for point in polyline.points {
//                    if path.contains(point.location) {
//                        return true
//                    }
//                }
//            }
//        }
//        return false
//    }
//
//    required init(drawingSize: CGSize, color: DrawingColor, lineWidth: CGFloat, arrow: Bool) {
//        self.drawingSize = drawingSize
//        self.color = color
//        self.lineWidth = lineWidth
//        self.arrow = arrow
//
//        self.renderArrowLength = min(drawingSize.width, drawingSize.height) * 0.04
//        self.renderArrowLineWidth = min(drawingSize.width, drawingSize.height) * 0.01
//    }
//
//    func setupRenderLayer() -> DrawingRenderLayer? {
//        let layer = RenderLayer()
//        layer.setup(size: self.drawingSize, color: self.color, lineWidth: self.lineWidth)
//        self.currentRenderLayer = layer
//        return layer
//    }
//
//    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
//        guard case let .polyline(polyline) = path else {
//            return
//        }
//
//        self.polyline = polyline
//
//        struct LineSegment {
//            var firstPoint: CGPoint
//            var secondPoint: CGPoint
//        }
//
//        func lineSegmentPerpendicularTo(_ pp: LineSegment, fraction: CGFloat) -> LineSegment {
//            let x0: CGFloat = pp.firstPoint.x
//            let y0: CGFloat = pp.firstPoint.y
//
//            let x1: CGFloat = pp.secondPoint.x
//            let y1: CGFloat = pp.secondPoint.y
//
//            let dx = x1 - x0
//            let dy = y1 - y0
//
//            var xa: CGFloat
//            var ya: CGFloat
//            var xb: CGFloat
//            var yb: CGFloat
//
//            xa = x1 + fraction * 0.5 * dy
//            ya = y1 - fraction * 0.5 * dx
//            xb = x1 - fraction * 0.5 * dy
//            yb = y1 + fraction * 0.5 * dx
//
//            return LineSegment(firstPoint: CGPoint(x: xa, y: ya), secondPoint: CGPoint(x: xb, y: yb))
//        }
//
//
//        func len_sq(_ p1: CGPoint, p2: CGPoint) -> CGFloat {
//            let dx: CGFloat = p2.x - p1.x
//            let dy: CGFloat = p2.y - p1.y
//            return dx * dx + dy * dy
//        }
//
//        func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
//            if (value < min) {
//                return min
//            }
//            if (value > max) {
//                return max
//            }
//            return value
//        }
//
//        var ls: [LineSegment] = []
//        var isFirst = true
//
//        let combinedPath = UIBezierPath()
//        var segmentPath = UIBezierPath()
//
//        var pts: [CGPoint] = []
//        var ctr: Int = 0
//
//        let ff: CGFloat = 0.2
//        let lower: CGFloat = 0.01
//        let upper: CGFloat = 1.0
//
//        var lastUsedIndex = 0
//        var index = 0
//        for point in polyline.points {
//            pts.insert(point.location, at: ctr)
//            ctr += 1
//
//            if ctr == 5 {
//                pts[3] = CGPoint(x: (pts[2].x + pts[4].x) / 2.0, y: (pts[2].y + pts[4].y) / 2.0)
//
//                if isFirst {
//                    isFirst = false
//                    let segment = LineSegment(firstPoint: pts[0], secondPoint: pts[0])
//                    ls.append(segment)
//                    segmentPath.move(to: pts[0])
//                }
//
//                let frac1: CGFloat = ff/clamp(len_sq(pts[0], p2: pts[1]), min: lower, max: upper)
//                let frac2: CGFloat = ff/clamp(len_sq(pts[1], p2: pts[2]), min: lower, max: upper)
//                let frac3: CGFloat = ff/clamp(len_sq(pts[2], p2: pts[3]), min: lower, max: upper)
//
//                ls.insert(lineSegmentPerpendicularTo(LineSegment(firstPoint: pts[0], secondPoint: pts[1]), fraction: frac1), at: 1)
//                ls.insert(lineSegmentPerpendicularTo(LineSegment(firstPoint: pts[1], secondPoint: pts[2]), fraction: frac2), at: 2)
//                ls.insert(lineSegmentPerpendicularTo(LineSegment(firstPoint: pts[2], secondPoint: pts[3]), fraction: frac3), at: 3)
//
//                segmentPath.move(to: ls[0].firstPoint)
//                segmentPath.addCurve(to: ls[3].firstPoint, controlPoint1: ls[1].firstPoint, controlPoint2: ls[2].firstPoint)
//                segmentPath.addLine(to: ls[3].secondPoint)
//                segmentPath.addCurve(to: ls[0].secondPoint, controlPoint1: ls[2].secondPoint, controlPoint2: ls[1].secondPoint)
//                segmentPath.close()
//                combinedPath.append(segmentPath)
//
//                let last = ls[3]
//                ls.removeAll()
//                ls.append(last)
//
//                pts[0] = pts[3]
//                pts[1] = pts[4]
//                ctr = 2
//
//                combinedPath.append(segmentPath)
//                segmentPath = UIBezierPath()
//
//                lastUsedIndex = index
//            }
//            index += 1
//        }
//
//        var lastPosition = polyline.points.last?.location ?? CGPoint()
//        if let lastPoint = polyline.points.last, ls.count > 0 {
//            if lastUsedIndex < polyline.points.count - 1 {
//                let frac1: CGFloat = ff/clamp(len_sq(pts[0], p2: pts[1]), min: lower, max: upper)
//                let frac2: CGFloat = ff/clamp(len_sq(pts[1], p2: lastPoint.location), min: lower, max: upper)
//                ls.insert(lineSegmentPerpendicularTo(LineSegment(firstPoint: pts[0], secondPoint: pts[1]), fraction: frac1), at: 1)
//                ls.insert(lineSegmentPerpendicularTo(LineSegment(firstPoint: pts[1], secondPoint: lastPoint.location), fraction: frac2), at: 2)
//
//                segmentPath.move(to: ls[0].firstPoint)
//                segmentPath.addQuadCurve(to: ls[2].firstPoint, controlPoint: ls[1].firstPoint)
//                segmentPath.addLine(to: ls[2].secondPoint)
//                segmentPath.addQuadCurve(to: ls[0].secondPoint, controlPoint: ls[1].secondPoint)
//                segmentPath.addLine(to: ls[0].secondPoint)
//                segmentPath.close()
//                combinedPath.append(segmentPath)
//
//                let diameter = ls[2].firstPoint.distance(to: ls[2].secondPoint)
//                combinedPath.append(UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: lastPoint.x - diameter * 0.5, y: lastPoint.y - diameter * 0.5), size: CGSize(width: diameter, height: diameter))))
//
//                lastPosition = lastPoint.location
//            } else {
//                let diameter = ls[0].firstPoint.distance(to: ls[0].secondPoint)
//                let center = ls[0].firstPoint.point(to: ls[0].secondPoint, t: 0.5)
//                combinedPath.append(UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: center.x - diameter * 0.5, y: center.y - diameter * 0.5), size: CGSize(width: diameter, height: diameter))))
//
//                lastPosition = center
//            }
//        }
//
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
//
//        if let currentRenderLayer = self.currentRenderLayer as? RenderLayer {
//            currentRenderLayer.updatePath(combinedPath.cgPath)
//        }
//    }
//
//    func draw(in context: CGContext, size: CGSize) {
//        let renderLayer: DrawingRenderLayer?
//        if let currentRenderLayer = self.currentRenderLayer {
//            renderLayer = currentRenderLayer
//        } else {
//            renderLayer = self.setupRenderLayer()
////            (renderLayer as? RenderLayer)?.updatePath(self.path.path.cgPath)
//        }
//        renderLayer?.render(in: context)
//    }
//}

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
        return self.renderPath.bounds
    }
    
    var points: [Polyline.Point] = []
    
    weak var metalView: DrawingMetalView?
    
    func containsPoint(_ point: CGPoint) -> Bool {
        return self.renderPath.contains(point)
    }
    
    func hasPointsInsidePath(_ path: UIBezierPath) -> Bool {
        let pathBoundingBox = path.bounds
        if self.bounds.intersects(pathBoundingBox) {
            for point in self.points {
                if path.contains(point.location) {
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
                
        let minLineWidth = max(10.0, min(drawingSize.width, drawingSize.height) * 0.01)
        let maxLineWidth = max(20.0, min(drawingSize.width, drawingSize.height) * 0.09)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        self.renderLineWidth = lineWidth
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        return nil
    }
    
    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
        guard case let .location(point) = path else {
            return
        }
        
        if self.points.isEmpty {
            self.renderPath.move(to: point.location)
        } else {
            self.renderPath.addLine(to: point.location)
        }
        self.points.append(point)
        
        self.metalView?.updated(point, state: state, brush: .marker, color: self.color, size: self.renderLineWidth)
    }
    
    func draw(in context: CGContext, size: CGSize) {
        guard !self.points.isEmpty else {
            return
        }
        
        self.metalView?.drawInContext(context)
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
        
        let minLineWidth = max(1.0, min(drawingSize.width, drawingSize.height) * 0.003)
        let maxLineWidth = max(10.0, min(drawingSize.width, drawingSize.height) * 0.09)
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
        return self.renderPath.bounds
    }
    
    var points: [Polyline.Point] = []
    
    weak var metalView: DrawingMetalView?
    
    func containsPoint(_ point: CGPoint) -> Bool {
        return self.renderPath.contains(point.offsetBy(dx: -self.translation.x, dy: -self.translation.y))
    }
    
    func hasPointsInsidePath(_ path: UIBezierPath) -> Bool {
        let pathBoundingBox = path.bounds
        if self.bounds.intersects(pathBoundingBox) {
            for point in self.points {
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
                
        let minLineWidth = max(10.0, min(drawingSize.width, drawingSize.height) * 0.01)
        let maxLineWidth = max(20.0, min(drawingSize.width, drawingSize.height) * 0.09)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        self.renderLineWidth = lineWidth
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        return nil
    }
    
    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
        guard case let .location(point) = path else {
            return
        }
        
        if self.points.isEmpty {
            self.renderPath.move(to: point.location)
        } else {
            self.renderPath.addLine(to: point.location)
        }
        self.points.append(point)
        
        self.metalView?.updated(point, state: state, brush: .pencil, color: self.color, size: self.renderLineWidth)
    }
    
    func draw(in context: CGContext, size: CGSize) {
        guard !self.points.isEmpty else {
            return
        }
        
        self.metalView?.drawInContext(context)
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
            
        let minLineWidth = max(1.0, min(drawingSize.width, drawingSize.height) * 0.003)
        let maxLineWidth = max(10.0, min(drawingSize.width, drawingSize.height) * 0.09)
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
            
        let minLineWidth = max(1.0, min(drawingSize.width, drawingSize.height) * 0.003)
        let maxLineWidth = max(10.0, min(drawingSize.width, drawingSize.height) * 0.09)
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
