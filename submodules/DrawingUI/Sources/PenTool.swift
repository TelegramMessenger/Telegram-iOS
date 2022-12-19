import Foundation
import UIKit
import Display

final class PenTool: DrawingElement {
    class RenderLayer: SimpleLayer, DrawingRenderLayer {
        func setup(size: CGSize) {
            self.shouldRasterize = true
            self.contentsScale = 1.0
            
            let bounds = CGRect(origin: .zero, size: size)
            self.frame = bounds
        }
        
        
        private var color: UIColor?
        private var line: StrokeLine?
        fileprivate func draw(line: StrokeLine, color: UIColor, rect: CGRect) {
            self.line = line
            self.color = color
            self.setNeedsDisplay(rect.insetBy(dx: -50.0, dy: -50.0))
        }
        
        func animateArrowPaths(leftArrowPath: UIBezierPath, rightArrowPath: UIBezierPath, lineWidth: CGFloat, completion: @escaping () -> Void) {
            let leftArrowShape = CAShapeLayer()
            leftArrowShape.path = leftArrowPath.cgPath
            leftArrowShape.lineWidth = lineWidth
            leftArrowShape.strokeColor = self.color?.cgColor
            leftArrowShape.lineCap = .round
            leftArrowShape.frame = self.bounds
            self.addSublayer(leftArrowShape)
            
            let rightArrowShape = CAShapeLayer()
            rightArrowShape.path = rightArrowPath.cgPath
            rightArrowShape.lineWidth = lineWidth
            rightArrowShape.strokeColor = self.color?.cgColor
            rightArrowShape.lineCap = .round
            rightArrowShape.frame = self.bounds
            self.addSublayer(rightArrowShape)
            
            leftArrowShape.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "strokeEnd", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
            rightArrowShape.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "strokeEnd", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, completion: { [weak leftArrowShape, weak rightArrowShape] _ in
                completion()
                
                leftArrowShape?.removeFromSuperlayer()
                rightArrowShape?.removeFromSuperlayer()
            })
        }
        
        override func draw(in ctx: CGContext) {
            self.line?.drawInContext(ctx)
        }
    }
    
    let uuid = UUID()
    
    let drawingSize: CGSize
    let color: DrawingColor
    let lineWidth: CGFloat
    let arrow: Bool
    
    var path: Polyline?
    var boundingBox: CGRect?
    
    private var renderLine: StrokeLine
    let renderLineWidth: CGFloat
    let renderArrowLength: CGFloat
    let renderArrowLineWidth: CGFloat
    
    var didSetupArrow = false
    var arrowLeftPath: UIBezierPath?
    var arrowLeftPoint: CGPoint?
    var arrowRightPath: UIBezierPath?
    var arrowRightPoint: CGPoint?
    
    var translation = CGPoint()
    
    private var currentRenderLayer: DrawingRenderLayer?
    
    var bounds: CGRect {
        return self.path?.bounds.offsetBy(dx: self.translation.x, dy: self.translation.y) ?? .zero
    }
    
    var points: [Polyline.Point] {
        guard let linePath = self.path else {
            return []
        }
        var points: [Polyline.Point] = []
        for point in linePath.points {
            points.append(point.offsetBy(self.translation))
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
                for point in linePath.points {
                    if path.contains(point.location.offsetBy(self.translation)) {
                        return true
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
        
        let minLineWidth = max(1.0, max(drawingSize.width, drawingSize.height) * 0.002)
        let maxLineWidth = max(10.0, max(drawingSize.width, drawingSize.height) * 0.07)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        self.renderLineWidth = lineWidth
        self.renderArrowLength = lineWidth * 3.0
        self.renderArrowLineWidth = lineWidth * 0.8
        
        self.renderLine = StrokeLine(color: color.toUIColor(), minLineWidth: minLineWidth + (lineWidth - minLineWidth) * 0.3, lineWidth: lineWidth)
    }
    
    func finishArrow(_ completion: @escaping () -> Void) {
        if let arrowLeftPath, let arrowRightPath {
            (self.currentRenderLayer as? RenderLayer)?.animateArrowPaths(leftArrowPath: arrowLeftPath, rightArrowPath: arrowRightPath, lineWidth: self.renderArrowLineWidth, completion: {
                completion()
            })
        } else {
            completion()
        }
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        let layer = RenderLayer()
        layer.setup(size: self.drawingSize)
        self.currentRenderLayer = layer
        return layer
    }
    
    var previousPoint: CGPoint?
    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
        guard case let .polyline(line) = path, let point = line.points.last else {
            return
        }
        self.path = line
        
        let filterDistance: CGFloat
        if point.velocity > 1200 {
            filterDistance = 75.0
        } else {
            filterDistance = 35.0
        }
        
        if let previousPoint, point.location.distance(to: previousPoint) < filterDistance, state == .changed, self.renderLine.ready {
            return
        }
        self.previousPoint = point.location
        
        let rect = self.renderLine.draw(at: point)
        if let currentRenderLayer = self.currentRenderLayer as? RenderLayer {
            currentRenderLayer.draw(line: self.renderLine, color: self.color.toUIColor(), rect: rect)
        }
        
        if state == .ended {
            if self.arrow {
                let points = self.path?.points ?? []
                
                var direction: CGFloat?
                if points.count > 4 {
                    let p2 = points[points.count - 1].location
                    for i in 1 ..< min(points.count - 2, 12) {
                        let p1 = points[points.count - 1 - i].location
                        if p1.distance(to: p2) > renderArrowLength * 0.5 {
                            direction = p2.angle(to: p1)
                            break
                        }
                    }
                }
                                
                if let point = points.last?.location, let direction {
                    let arrowLeftPath = UIBezierPath()
                    arrowLeftPath.move(to: point)
                    let leftPoint = point.pointAt(distance: self.renderArrowLength, angle: direction - 0.45)
                    arrowLeftPath.addLine(to: leftPoint)
                    
                    let arrowRightPath = UIBezierPath()
                    arrowRightPath.move(to: point)
                    let rightPoint = point.pointAt(distance: self.renderArrowLength, angle: direction + 0.45)
                    arrowRightPath.addLine(to: rightPoint)
                    
                    self.arrowLeftPath = arrowLeftPath
                    self.arrowLeftPoint = leftPoint
                    
                    self.arrowRightPath = arrowRightPath
                    self.arrowRightPoint = rightPoint
                }
            }
        }
    }
    
    func draw(in context: CGContext, size: CGSize) {
        context.saveGState()
        
        context.translateBy(x: self.translation.x, y: self.translation.y)
        
        context.setShouldAntialias(true)
        
        self.renderLine.drawInContext(context)
        
        if let arrowLeftPath, let arrowRightPath {
            context.setStrokeColor(self.color.toCGColor())
            context.setLineWidth(self.renderArrowLineWidth)
            context.setLineCap(.round)
            
            context.addPath(arrowLeftPath.cgPath)
            context.strokePath()
            
            context.addPath(arrowRightPath.cgPath)
            context.strokePath()
        }
        
        context.restoreGState()
    }
}

private class StrokeLine {
    struct Segment {
        let a: CGPoint
        let b: CGPoint
        let c: CGPoint
        let d: CGPoint
        let abWidth: CGFloat
        let cdWidth: CGFloat
    }
    
    struct Point {
        let position: CGPoint
        let width: CGFloat
        
        init(position: CGPoint, width: CGFloat) {
            self.position = position
            self.width = width
        }
    }
    
    private(set) var points: [Point] = []
    private var smoothPoints: [Point] = []
    private var segments: [Segment] = []

    private let minLineWidth: CGFloat
    let lineWidth: CGFloat
    private var lastWidth: CGFloat?
    
    var ready = false
    
    let color: UIColor
    
    init(color: UIColor, minLineWidth: CGFloat, lineWidth: CGFloat) {
        self.color = color
        self.minLineWidth = minLineWidth
        self.lineWidth = lineWidth
    }
    
    func draw(at point: Polyline.Point) -> CGRect {
        var velocity = point.velocity
        if velocity.isZero {
            velocity = 600.0
        }
        let width = extractLineWidth(from: velocity)
        self.lastWidth = width
        
        let point = Point(position: point.location, width: width)
        return appendPoint(point)
    }
    
    func drawInContext(_ context: CGContext) {
        self.drawSegments(self.segments, inContext: context)
    }
    
    func extractLineWidth(from velocity: CGFloat) -> CGFloat {
        let minValue = self.minLineWidth
        let maxValue = self.lineWidth
        
        var width = max(minValue, min(maxValue + 1.0 - (velocity / 180.0), maxValue))
        if let lastWidth = self.lastWidth {
            width = width * 0.2 + lastWidth * 0.8
        }
        return width
    }
    
    func appendPoint(_ point: Point) -> CGRect {
        self.points.append(point)
        
        guard self.points.count > 2 else { return .null }
        
        let index = self.points.count - 1
        let point0 = self.points[index - 2]
        let point1 = self.points[index - 1]
        let point2 = self.points[index]
        
        let newSmoothPoints = smoothPoints(
            fromPoint0: point0,
            point1: point1,
            point2: point2
        )
        
        let lastOldSmoothPoint = smoothPoints.last
        smoothPoints.append(contentsOf: newSmoothPoints)
        
        guard smoothPoints.count > 1 else { return .null }
        
        let newSegments: ([Segment], CGRect) = {
            guard let lastOldSmoothPoint = lastOldSmoothPoint else {
                return segments(fromSmoothPoints: newSmoothPoints)
            }
            return segments(fromSmoothPoints: [lastOldSmoothPoint] + newSmoothPoints)
        }()
        segments.append(contentsOf: newSegments.0)
        
        self.ready = true
        
        return newSegments.1
    }
    
    func smoothPoints(fromPoint0 point0: Point, point1: Point, point2: Point) -> [Point] {
        var smoothPoints = [Point]()
        
        let midPoint1 = (point0.position + point1.position) * 0.5
        let midPoint2 = (point1.position + point2.position) * 0.5
        
        let segmentDistance = 3.0
        let distance = midPoint1.distance(to: midPoint2)
        let numberOfSegments = min(128, max(floor(distance / segmentDistance), 32))
        
        let step = 1.0 / numberOfSegments
        for t in stride(from: 0, to: 1, by: step) {
            let position = midPoint1 * pow(1 - t, 2) + point1.position * 2 * (1 - t) * t + midPoint2 * t * t
            let size = pow(1 - t, 2) * ((point0.width + point1.width) * 0.5) + 2 * (1 - t) * t * point1.width + t * t * ((point1.width + point2.width) * 0.5)
            let point = Point(position: position, width: size)
            smoothPoints.append(point)
        }
        
        let finalPoint = Point(position: midPoint2, width: (point1.width + point2.width) * 0.5)
        smoothPoints.append(finalPoint)
        
        return smoothPoints
    }
    
    func segments(fromSmoothPoints smoothPoints: [Point]) -> ([Segment], CGRect) {
        var segments: [Segment] = []
        var updateRect = CGRect.null
        for i in 1 ..< smoothPoints.count {
            let previousPoint = smoothPoints[i - 1].position
            let previousWidth = smoothPoints[i - 1].width
            let currentPoint = smoothPoints[i].position
            let currentWidth = smoothPoints[i].width
            let direction = currentPoint - previousPoint
            
            guard !currentPoint.isEqual(to: previousPoint, epsilon: 0.0001) else {
                continue
            }
            
            var perpendicular = CGPoint(x: -direction.y, y: direction.x)
            let length = perpendicular.length
            if length > 0.0 {
                perpendicular = perpendicular / length
            }
            
            let a = previousPoint + perpendicular * previousWidth / 2
            let b = previousPoint - perpendicular * previousWidth / 2
            let c = currentPoint + perpendicular * currentWidth / 2
            let d = currentPoint - perpendicular * currentWidth / 2
            
            let ab: CGPoint = {
                let center = (b + a) / 2
                let radius = center - b
                return .init(x: center.x - radius.y, y: center.y + radius.x)
            }()
            let cd: CGPoint = {
                let center = (c + d) / 2
                let radius = center - c
                return .init(x: center.x + radius.y, y: center.y - radius.x)
            }()
            
            let minX = min(a.x, b.x, c.x, d.x, ab.x, cd.x)
            let minY = min(a.y, b.y, c.y, d.y, ab.y, cd.y)
            let maxX = max(a.x, b.x, c.x, d.x, ab.x, cd.x)
            let maxY = max(a.y, b.y, c.y, d.y, ab.y, cd.y)
            
            updateRect = updateRect.union(CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
            
            segments.append(Segment(a: a, b: b, c: c, d: d, abWidth: previousWidth, cdWidth: currentWidth))
        }
        return (segments, updateRect)
    }
    
    func drawSegments(_ segments: [Segment], inContext context: CGContext) {
        for segment in segments {
            context.beginPath()

            //let color = [UIColor.red, UIColor.green, UIColor.blue, UIColor.yellow].randomElement()!
            
            context.setStrokeColor(color.cgColor)
            context.setFillColor(color.cgColor)
            
            context.move(to: segment.b)
            
            let abStartAngle = atan2(segment.b.y - segment.a.y, segment.b.x - segment.a.x)
            context.addArc(
                center: (segment.a + segment.b)/2,
                radius: segment.abWidth/2,
                startAngle: abStartAngle,
                endAngle: abStartAngle + .pi,
                clockwise: true
            )
            context.addLine(to: segment.c)
            
            let cdStartAngle = atan2(segment.c.y - segment.d.y, segment.c.x - segment.d.x)
            context.addArc(
                center: (segment.c + segment.d) / 2,
                radius: segment.cdWidth/2,
                startAngle: cdStartAngle,
                endAngle: cdStartAngle + .pi,
                clockwise: true
            )
            context.closePath()
            
            context.fillPath()
            context.strokePath()
        }
    }
}
