import Foundation
import UIKit
import Display

final class PenTool: DrawingElement, Codable {    
    class RenderLayer: SimpleLayer, DrawingRenderLayer {
        private weak var element: PenTool?
        
        private var segmentsCount = 0
        private var velocity: CGFloat?
        private var previousRect: CGRect?
        
        var displayLink: ConstantDisplayLinkAnimator?
        func setup(size: CGSize) {
            self.shouldRasterize = true
            self.contentsScale = 1.0
            
            let bounds = CGRect(origin: .zero, size: size)
            self.frame = bounds
            
            self.displayLink = ConstantDisplayLinkAnimator(update: { [weak self] in
                if let strongSelf = self {
                    if let element = strongSelf.element, strongSelf.segmentsCount < element.segments.count, let velocity = strongSelf.velocity {
                        let delta = max(9, Int(velocity / 100.0))
                        let start = strongSelf.segmentsCount
                        strongSelf.segmentsCount = min(strongSelf.segmentsCount + delta, element.segments.count)
                        
                        let rect = element.boundingRect(from: start, to: strongSelf.segmentsCount)
                        strongSelf.setNeedsDisplay(rect.insetBy(dx: -80.0, dy: -80.0))
                    }
                }
            })
            self.displayLink?.frameInterval = 1
            self.displayLink?.isPaused = false
        }
        

        fileprivate func draw(element: PenTool, velocity: CGFloat, rect: CGRect) {
            self.element = element
            
            self.previousRect = rect
            if let previous = self.velocity {
                self.velocity = velocity * 0.4 + previous * 0.6
            } else {
                self.velocity = velocity
            }
            self.setNeedsDisplay(rect.insetBy(dx: -80.0, dy: -80.0))
        }
        
        func animateArrowPaths(leftArrowPath: UIBezierPath, rightArrowPath: UIBezierPath, lineWidth: CGFloat, completion: @escaping () -> Void) {
            let leftArrowShape = CAShapeLayer()
            leftArrowShape.path = leftArrowPath.cgPath
            leftArrowShape.lineWidth = lineWidth
            leftArrowShape.strokeColor = self.element?.color.toCGColor()
            leftArrowShape.lineCap = .round
            leftArrowShape.frame = self.bounds
            self.addSublayer(leftArrowShape)
            
            let rightArrowShape = CAShapeLayer()
            rightArrowShape.path = rightArrowPath.cgPath
            rightArrowShape.lineWidth = lineWidth
            rightArrowShape.strokeColor = self.element?.color.toCGColor()
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
            self.element?.drawSegments(in: ctx, upTo: self.segmentsCount)
        }
    }
    
    let uuid: UUID
    let drawingSize: CGSize
    let color: DrawingColor
    let renderLineWidth: CGFloat
    let renderMinLineWidth: CGFloat
    
    let hasArrow: Bool
    let renderArrowLength: CGFloat
    let renderArrowLineWidth: CGFloat
        
    var arrowLeftPath: UIBezierPath?
    var arrowRightPath: UIBezierPath?
    
    var translation: CGPoint = .zero
    
    private weak var currentRenderLayer: DrawingRenderLayer?
    
    required init(drawingSize: CGSize, color: DrawingColor, lineWidth: CGFloat, hasArrow: Bool) {
        self.uuid = UUID()
        self.drawingSize = drawingSize
        self.color = color
        self.hasArrow = hasArrow
        
        let minLineWidth = max(1.0, max(drawingSize.width, drawingSize.height) * 0.002)
        let maxLineWidth = max(10.0, max(drawingSize.width, drawingSize.height) * 0.07)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        self.renderLineWidth = lineWidth
        self.renderMinLineWidth = minLineWidth + (lineWidth - minLineWidth) * 0.3
        self.renderArrowLength = lineWidth * 3.0
        self.renderArrowLineWidth = lineWidth * 0.8
    }
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case drawingSize
        case color
        case hasArrow
        
        case renderLineWidth
        case renderMinLineWidth
        case renderArrowLength
        case renderArrowLineWidth
        
        case renderSegments
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(UUID.self, forKey: .uuid)
        self.drawingSize = try container.decode(CGSize.self, forKey: .drawingSize)
        self.color = try container.decode(DrawingColor.self, forKey: .color)
        self.hasArrow = try container.decode(Bool.self, forKey: .hasArrow)
        self.renderLineWidth = try container.decode(CGFloat.self, forKey: .renderLineWidth)
        self.renderMinLineWidth = try container.decode(CGFloat.self, forKey: .renderMinLineWidth)
        self.renderArrowLength = try container.decode(CGFloat.self, forKey: .renderArrowLength)
        self.renderArrowLineWidth = try container.decode(CGFloat.self, forKey: .renderArrowLineWidth)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.uuid, forKey: .uuid)
        try container.encode(self.drawingSize, forKey: .drawingSize)
        try container.encode(self.color, forKey: .color)
        try container.encode(self.hasArrow, forKey: .hasArrow)
        try container.encode(self.renderLineWidth, forKey: .renderLineWidth)
        try container.encode(self.renderMinLineWidth, forKey: .renderMinLineWidth)
        try container.encode(self.renderArrowLength, forKey: .renderArrowLength)
        try container.encode(self.renderArrowLineWidth, forKey: .renderArrowLineWidth)
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
    
        let filterDistance: CGFloat
        if point.velocity > 1200.0 {
            filterDistance = 75.0
        } else {
            filterDistance = 35.0
        }
        
        if let previousPoint, point.location.distance(to: previousPoint) < filterDistance, state == .changed, self.segments.count > 0 {
            return
        }
        self.previousPoint = point.location
        
        var velocity = point.velocity
        if velocity.isZero {
            velocity = 600.0
        }
        
        var effectiveRenderLineWidth = max(self.renderMinLineWidth, min(self.renderLineWidth + 1.0 - (velocity / 180.0), self.renderLineWidth))
        if let previousRenderLineWidth = self.previousRenderLineWidth {
            effectiveRenderLineWidth = effectiveRenderLineWidth * 0.2 + previousRenderLineWidth * 0.8
        }
        self.previousRenderLineWidth = effectiveRenderLineWidth
        
        let rect = append(point: Point(position: point.location, width: effectiveRenderLineWidth))
        
        if let currentRenderLayer = self.currentRenderLayer as? RenderLayer, let rect = rect {
            currentRenderLayer.draw(element: self, velocity: point.velocity, rect: rect)
        }
        
        if state == .ended {
            if self.hasArrow {
                var direction: CGFloat?
                if self.smoothPoints.count > 4 {
                    let p2 = self.smoothPoints[self.smoothPoints.count - 1].position
                    for i in 1 ..< min(self.smoothPoints.count - 2, 12) {
                        let p1 = self.smoothPoints[self.smoothPoints.count - 1 - i].position
                        if p1.distance(to: p2) > self.renderArrowLength * 0.5 {
                            direction = p2.angle(to: p1)
                            break
                        }
                    }
                }
                                
                if let point = self.smoothPoints.last?.position, let direction {
                    let arrowLeftPath = UIBezierPath()
                    arrowLeftPath.move(to: point)
                    arrowLeftPath.addLine(to: point.pointAt(distance: self.renderArrowLength, angle: direction - 0.45))
                    
                    let arrowRightPath = UIBezierPath()
                    arrowRightPath.move(to: point)
                    arrowRightPath.addLine(to: point.pointAt(distance: self.renderArrowLength, angle: direction + 0.45))
                    
                    self.arrowLeftPath = arrowLeftPath
                    self.arrowRightPath = arrowRightPath
                }
            }
        }
    }
    
    func draw(in context: CGContext, size: CGSize) {
        guard !self.segments.isEmpty else {
            return
        }
        
        context.saveGState()
        
        context.translateBy(x: self.translation.x, y: self.translation.y)
        
        context.setShouldAntialias(true)
        
        self.drawSegments(in: context, upTo: self.segments.count)
        
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
    
    private struct Segment {
        let a: CGPoint
        let b: CGPoint
        let c: CGPoint
        let d: CGPoint
        let radius1: CGFloat
        let radius2: CGFloat
        let rect: CGRect
    }
    
    private struct Point {
        let position: CGPoint
        let width: CGFloat
        
        init(
            position: CGPoint,
            width: CGFloat
        ) {
            self.position = position
            self.width = width
        }
    }
    
    private var points: [Point] = []
    private var smoothPoints: [Point] = []
    private var segments: [Segment] = []
    
    private var previousRenderLineWidth: CGFloat?
    
    private func append(point: Point) -> CGRect? {
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
        self.smoothPoints.append(contentsOf: newSmoothPoints)
        
        guard self.smoothPoints.count > 1 else {
            return nil
        }
        
        let newSegments: ([Segment], CGRect) = {
            guard let lastOldSmoothPoint = lastOldSmoothPoint else {
                return segments(fromSmoothPoints: newSmoothPoints)
            }
            return segments(fromSmoothPoints: [lastOldSmoothPoint] + newSmoothPoints)
        }()
        self.segments.append(contentsOf: newSegments.0)
                
        return newSegments.1
    }
    
    private func smoothPoints(fromPoint0 point0: Point, point1: Point, point2: Point) -> [Point] {
        var smoothPoints: [Point] = []
        
        let midPoint1 = (point0.position + point1.position) * 0.5
        let midPoint2 = (point1.position + point2.position) * 0.5
        
        let segmentDistance: CGFloat = 3.0
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
    
    fileprivate func boundingRect(from: Int, to: Int) -> CGRect {
        var minX: CGFloat = .greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = 0.0
        var maxY: CGFloat = 0.0
        
        for i in from ..< to {
            let segment = self.segments[i]
            
            if segment.rect.minX < minX {
                minX = segment.rect.minX
            }
            if segment.rect.maxX > maxX {
                maxX = segment.rect.maxX
            }
            if segment.rect.minY < minY {
                minY = segment.rect.minY
            }
            if segment.rect.maxY > maxY {
                maxY = segment.rect.maxY
            }
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func segments(fromSmoothPoints smoothPoints: [Point]) -> ([Segment], CGRect) {
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
            
            let segmentRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            updateRect = updateRect.union(segmentRect)
            
            segments.append(Segment(a: a, b: b, c: c, d: d, radius1: previousWidth / 2.0, radius2: currentWidth / 2.0, rect: segmentRect))
        }
        return (segments, updateRect)
    }
    
    private func drawSegments(in context: CGContext, upTo: Int) {
        context.setStrokeColor(self.color.toCGColor())
        context.setFillColor(self.color.toCGColor())
        
        for i in 0 ..< upTo {
            let segment = self.segments[i]
            context.beginPath()
                        
            context.move(to: segment.b)
            
            let abStartAngle = atan2(
                segment.b.y - segment.a.y,
                segment.b.x - segment.a.x
            )
            context.addArc(
                center: (segment.a + segment.b)/2,
                radius: segment.radius1,
                startAngle: abStartAngle,
                endAngle: abStartAngle + .pi,
                clockwise: true
            )
            context.addLine(to: segment.c)
            
            let cdStartAngle = atan2(
                segment.c.y - segment.d.y,
                segment.c.x - segment.d.x
            )
            context.addArc(
                center: (segment.c + segment.d) / 2,
                radius: segment.radius2,
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

