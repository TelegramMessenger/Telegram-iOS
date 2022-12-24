import Foundation
import UIKit
import Display

final class PenTool: DrawingElement {
    class RenderView: UIView, DrawingRenderView {
        private weak var element: PenTool?
        private var isEraser = false
        
        private var accumulationImage: UIImage?
        private var activeView: ActiveView?
        
        private var start = 0
        private var segmentsCount = 0
        
        private var drawScale = CGSize(width: 1.0, height: 1.0)
        
        func setup(size: CGSize, screenSize: CGSize, isEraser: Bool) {
            self.isEraser = isEraser
            
            self.backgroundColor = .clear
            self.isOpaque = false
            self.contentMode = .redraw
            
            //let scale = CGSize(width: screenSize.width / max(1.0, size.width), height: screenSize.height / max(1.0, size.height))
            
            let scale = CGSize(width: 0.33, height: 0.33)
            let viewSize = CGSize(width: size.width * scale.width, height: size.height * scale.height)
            
            self.drawScale = CGSize(width: size.width / viewSize.width, height: size.height / viewSize.height)
            
            self.bounds = CGRect(origin: .zero, size: viewSize)
            self.transform = CGAffineTransform(scaleX: self.drawScale.width, y: self.drawScale.height)
            self.frame = CGRect(origin: .zero, size: size)
                        
            self.drawScale.height = self.drawScale.width
            
            let activeView = ActiveView(frame: CGRect(origin: .zero, size: self.bounds.size))
            activeView.backgroundColor = .clear
            activeView.contentMode = .redraw
            activeView.isOpaque = false
            activeView.parent = self
            self.addSubview(activeView)
            self.activeView = activeView
        }
        
        func animateArrowPaths(start: CGPoint, direction: CGFloat, length: CGFloat, lineWidth: CGFloat, completion: @escaping () -> Void) {
            let scale = min(self.drawScale.width, self.drawScale.height)
            
            let arrowStart = CGPoint(x: start.x / scale, y: start.y / scale)
            let arrowLeftPath = UIBezierPath()
            arrowLeftPath.move(to: arrowStart)
            arrowLeftPath.addLine(to: arrowStart.pointAt(distance: length / scale, angle: direction - 0.45))
            
            let arrowRightPath = UIBezierPath()
            arrowRightPath.move(to: arrowStart)
            arrowRightPath.addLine(to: arrowStart.pointAt(distance: length / scale, angle: direction + 0.45))
            
            let leftArrowShape = CAShapeLayer()
            leftArrowShape.path = arrowLeftPath.cgPath
            leftArrowShape.lineWidth = lineWidth / scale
            leftArrowShape.strokeColor = self.element?.color.toCGColor()
            leftArrowShape.lineCap = .round
            leftArrowShape.frame = self.bounds
            self.layer.addSublayer(leftArrowShape)
            
            let rightArrowShape = CAShapeLayer()
            rightArrowShape.path = arrowRightPath.cgPath
            rightArrowShape.lineWidth = lineWidth / scale
            rightArrowShape.strokeColor = self.element?.color.toCGColor()
            rightArrowShape.lineCap = .round
            rightArrowShape.frame = self.bounds
            self.layer.addSublayer(rightArrowShape)
            
            leftArrowShape.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "strokeEnd", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
            rightArrowShape.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "strokeEnd", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, completion: { [weak leftArrowShape, weak rightArrowShape] _ in
                completion()
                
                leftArrowShape?.removeFromSuperlayer()
                rightArrowShape?.removeFromSuperlayer()
            })
        }
    
        var displaySize: CGSize?
        fileprivate func draw(element: PenTool, rect: CGRect) {
            self.element = element
            
            self.alpha = element.color.alpha
            
            guard !rect.isInfinite && !rect.isEmpty && !rect.isNull else {
                return
            }
            
            var rect: CGRect? = rect

            let limit = 512
            let activeCount = self.segmentsCount - self.start
            if activeCount > limit {
                rect = nil
                let newStart = self.start + limit
                let displaySize = self.displaySize ?? CGSize(width: round(self.bounds.size.width), height: round(self.bounds.size.height))
                let image = generateImage(displaySize, contextGenerator: { size, context in
                    context.clear(CGRect(origin: .zero, size: size))
                    
                    if let accumulationImage = self.accumulationImage, let cgImage = accumulationImage.cgImage {
                        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
                    }
                    
                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                    
                    context.scaleBy(x: 1.0 / self.drawScale.width, y: 1.0 / self.drawScale.height)
                    
                    context.setBlendMode(.copy)
                    element.drawSegments(in: context, from: self.start, to: newStart)
                }, opaque: false)
                self.accumulationImage = image
                self.layer.contents = image?.cgImage
                
                self.start = newStart
            }
            
            self.segmentsCount = element.segments.count
            
            if let rect = rect {
                self.activeView?.setNeedsDisplay(rect.insetBy(dx: -10.0, dy: -10.0).applying(CGAffineTransform(scaleX: 1.0 / self.drawScale.width, y: 1.0 / self.drawScale.height)))
            } else {
                self.activeView?.setNeedsDisplay()
            }
        }
        
        class ActiveView: UIView {
            weak var parent: RenderView?
            override func draw(_ rect: CGRect) {
                guard let context = UIGraphicsGetCurrentContext(), let parent = self.parent, let element = parent.element else {
                    return
                }
                                
                parent.displaySize = rect.size
                context.scaleBy(x: 1.0 / parent.drawScale.width, y: 1.0 / parent.drawScale.height)
                element.drawSegments(in: context, from: parent.start, to: parent.segmentsCount)
            }
        }
    }
        
    let uuid: UUID
    let drawingSize: CGSize
    let color: DrawingColor
    let renderLineWidth: CGFloat
    let renderMinLineWidth: CGFloat
    let renderColor: UIColor
    
    let hasArrow: Bool
    let renderArrowLength: CGFloat
    let renderArrowLineWidth: CGFloat
    
    let isEraser: Bool
    
    let isBlur: Bool
    
    var arrowStart: CGPoint?
    var arrowDirection: CGFloat?
    var arrowLeftPath: UIBezierPath?
    var arrowRightPath: UIBezierPath?
    
    var translation: CGPoint = .zero
        
    var blurredImage: UIImage?
    
    private weak var currentRenderView: DrawingRenderView?
        
    var isValid: Bool {
        if self.hasArrow {
            return self.arrowStart != nil && self.arrowDirection != nil
        } else {
            return self.segments.count > 0
        }
    }
    
    var bounds: CGRect {
        return boundingRect(from: 0, to: self.segments.count).insetBy(dx: -20.0, dy: -20.0)
    }
    
    required init(drawingSize: CGSize, color: DrawingColor, lineWidth: CGFloat, hasArrow: Bool, isEraser: Bool, isBlur: Bool, blurredImage: UIImage?) {
        self.uuid = UUID()
        self.drawingSize = drawingSize
        self.color = isEraser || isBlur ? DrawingColor(rgb: 0x000000) : color
        self.hasArrow = hasArrow
        self.isEraser = isEraser
        self.isBlur = isBlur
        self.blurredImage = blurredImage
        
        let minLineWidth = max(1.0, max(drawingSize.width, drawingSize.height) * 0.002)
        let maxLineWidth = max(10.0, max(drawingSize.width, drawingSize.height) * 0.07)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        let minRenderArrowLength = max(10.0, max(drawingSize.width, drawingSize.height) * 0.02)
        
        self.renderLineWidth = lineWidth
        self.renderMinLineWidth = isEraser || isBlur ? lineWidth : minLineWidth + (lineWidth - minLineWidth) * 0.2
        self.renderArrowLength = max(minRenderArrowLength, lineWidth * 3.0)
        self.renderArrowLineWidth = max(minLineWidth * 1.8, lineWidth * 0.75)
        
        self.renderColor = color.withUpdatedAlpha(1.0).toUIColor()
    }
        
    var isFinishingArrow = false
    func finishArrow(_ completion: @escaping () -> Void) {
        if let arrowStart, let arrowDirection {
            self.isFinishingArrow = true
            (self.currentRenderView as? RenderView)?.animateArrowPaths(start: arrowStart, direction: arrowDirection, length: self.renderArrowLength, lineWidth: self.renderArrowLineWidth, completion: { [weak self] in
                self?.isFinishingArrow = false
                completion()
            })
        } else {
            completion()
        }
    }
    
    func setupRenderView(screenSize: CGSize) -> DrawingRenderView? {
        let view = RenderView()
        view.setup(size: self.drawingSize, screenSize: screenSize, isEraser: self.isEraser)
        self.currentRenderView = view
        return view
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        return nil
    }
    
    var previousPoint: CGPoint?
    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
        guard case let .point(point) = path else {
            return
        }
        
        let filterDistance: CGFloat = 20.0
        if let previousPoint, point.location.distance(to: previousPoint) < filterDistance, state == .changed, self.segments.count > 1 {
            return
        }
        self.previousPoint = point.location
        
        var velocity = point.velocity
        if velocity.isZero {
            velocity = 1000.0
        }
        
        var effectiveRenderLineWidth = max(self.renderMinLineWidth, min(self.renderLineWidth - (velocity / 100.0), self.renderLineWidth))
        if let previousRenderLineWidth = self.previousRenderLineWidth {
            effectiveRenderLineWidth = effectiveRenderLineWidth * 0.2 + previousRenderLineWidth * 0.8
        }
        self.previousRenderLineWidth = effectiveRenderLineWidth
        
        let rect = append(point: Point(position: point.location, width: effectiveRenderLineWidth))
        if let currentRenderView = self.currentRenderView as? RenderView, let rect = rect {
            currentRenderView.draw(element: self, rect: rect)
        }
        
        if state == .ended {
            if self.hasArrow {
                var direction: CGFloat?
                if self.smoothPoints.count > 4 {
                    let p2 = self.smoothPoints[self.smoothPoints.count - 1].position
                    for i in 1 ..< min(self.smoothPoints.count - 2, 200) {
                        let p1 = self.smoothPoints[self.smoothPoints.count - 1 - i].position
                        if p1.distance(to: p2) > self.renderArrowLength * 0.5 {
                            direction = p2.angle(to: p1)
                            break
                        }
                    }
                }
                
                self.arrowStart = self.smoothPoints.last?.position
                self.arrowDirection = direction
                self.maybeSetupArrow()
            } else if self.segments.isEmpty {
                let radius = self.renderLineWidth / 2.0
                self.segments.append(
                    Segment(
                        a: CGPoint(x: point.x - radius, y: point.y),
                        b: CGPoint(x: point.x + radius, y: point.y),
                        c: CGPoint(x: point.x - radius, y: point.y + 0.1),
                        d: CGPoint(x: point.x + radius, y: point.y + 0.1),
                        radius1: radius,
                        radius2: radius,
                        rect: .zero
                    )
                )
            }
        }
    }
    
    func maybeSetupArrow() {
        if let start = self.arrowStart, let direction = self.arrowDirection {
            let arrowLeftPath = UIBezierPath()
            arrowLeftPath.move(to: start)
            arrowLeftPath.addLine(to: start.pointAt(distance: self.renderArrowLength, angle: direction - 0.45))
            
            let arrowRightPath = UIBezierPath()
            arrowRightPath.move(to: start)
            arrowRightPath.addLine(to: start.pointAt(distance: self.renderArrowLength, angle: direction + 0.45))
            
            self.arrowLeftPath = arrowLeftPath
            self.arrowRightPath = arrowRightPath
        }
    }
    
    func draw(in context: CGContext, size: CGSize) {
        guard !self.segments.isEmpty else {
            return
        }
        
        context.saveGState()
        
        if self.isEraser {
            context.setBlendMode(.clear)
        } else if self.isBlur {
            context.setBlendMode(.normal)
        } else {
            context.setAlpha(self.color.alpha)
            context.setBlendMode(.copy)
        }
        
        context.translateBy(x: self.translation.x, y: self.translation.y)
        
        context.setShouldAntialias(true)
        
        if self.isBlur, let blurredImage = self.blurredImage {
            let maskContext = DrawingContext(size: size, scale: 0.5, clear: true)
            maskContext?.withFlippedContext { maskContext in
                self.drawSegments(in: maskContext, from: 0, to: self.segments.count)
            }
            if let maskImage = maskContext?.generateImage()?.cgImage, let blurredImage = blurredImage.cgImage {
                context.clip(to: CGRect(origin: .zero, size: size), mask: maskImage)
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                context.draw(blurredImage, in: CGRect(origin: .zero, size: size))
            }
            
        } else {
            self.drawSegments(in: context, from: 0, to: self.segments.count)
        }
        
        if let arrowLeftPath, let arrowRightPath {
            context.setStrokeColor(self.renderColor.cgColor)
            context.setLineWidth(self.renderArrowLineWidth)
            context.setLineCap(.round)
            
            context.addPath(arrowLeftPath.cgPath)
            context.strokePath()
            
            context.addPath(arrowRightPath.cgPath)
            context.strokePath()
        }
        
        context.restoreGState()
        
        self.segmentPaths = [:]
    }
    
    private struct Segment: Codable {
        let a: CGPoint
        let b: CGPoint
        let c: CGPoint
        let d: CGPoint
        let radius1: CGFloat
        let radius2: CGFloat
        let rect: CGRect
                
        init(a: CGPoint, b: CGPoint, c: CGPoint, d: CGPoint, radius1: CGFloat, radius2: CGFloat, rect: CGRect) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.radius1 = radius1
            self.radius2 = radius2
            self.rect = rect
        }
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
        
        guard self.points.count > 2 else { return nil }
        
        let index = self.points.count - 1
        let point0 = self.points[index - 2]
        let point1 = self.points[index - 1]
        let point2 = self.points[index]
        
        var newSmoothPoints = self.smoothPoints(
            fromPoint0: point0,
            point1: point1,
            point2: point2
        )
        
        let previousSmoothPoint = self.smoothPoints.last
        self.smoothPoints.append(contentsOf: newSmoothPoints)
        
        guard self.smoothPoints.count > 1 else {
            return nil
        }
        
        if let previousSmoothPoint = previousSmoothPoint {
            newSmoothPoints.insert(previousSmoothPoint, at: 0)
        }
        let (nextSegments, rect) = self.segments(fromSmoothPoints: newSmoothPoints)
        self.segments.append(contentsOf: nextSegments)
        
        for i in self.segments.count - nextSegments.count ..< self.segments.count {
            let segment = self.segments[i]
            let path = self.pathForSegment(segment)
            self.segmentPaths[i] = path
        }
                
        return rect
    }
    
    private func smoothPoints(fromPoint0 point0: Point, point1: Point, point2: Point) -> [Point] {
        var smoothPoints: [Point] = []
        
        let midPoint1 = CGPoint(
            x: (point0.position.x + point1.position.x) * 0.5,
            y: (point0.position.y + point1.position.y) * 0.5
        )
        let midPoint2 = CGPoint(
            x: (point1.position.x + point2.position.x) * 0.5,
            y: (point1.position.y + point2.position.y) * 0.5
        )
        
        let midWidth1 = (point0.width + point1.width) * 0.5
        let midWidth2 = (point1.width + point2.width) * 0.5
        
        let segmentDistance: CGFloat = 6.0
        let distance = midPoint1.distance(to: midPoint2)
        let numberOfSegments = min(48, max(floor(distance / segmentDistance), 24))
        
        let step = 1.0 / numberOfSegments
        for t in stride(from: 0, to: 1, by: step) {
            let x = midPoint1.x * pow(1 - t, 2) + point1.position.x * 2.0 * (1 - t) * t + midPoint2.x * t * t
            let y = midPoint1.y * pow(1 - t, 2) + point1.position.y * 2.0 * (1 - t) * t + midPoint2.y * t * t
            let w = midWidth1 * pow(1 - t, 2) + point1.width * 2.0 * (1 - t) * t + midWidth2 * t * t
         
            smoothPoints.append(Point(position: CGPoint(x: x, y: y), width: w))
        }
        
        smoothPoints.append(Point(position: midPoint2, width: midWidth2))
        
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
    
    private func segments(fromSmoothPoints smoothPoints: [Point]) -> ([Segment], CGRect?) {
        var segments: [Segment] = []
        var updateRect = CGRect.null
        for i in 1 ..< smoothPoints.count {
            let previousPoint = smoothPoints[i - 1].position
            let previousWidth = smoothPoints[i - 1].width
            let currentPoint = smoothPoints[i].position
            let currentWidth = smoothPoints[i].width
            let direction = CGPoint(
                x: currentPoint.x - previousPoint.x,
                y: currentPoint.y - previousPoint.y
            )
            
            guard !currentPoint.isEqual(to: previousPoint, epsilon: 0.0001) else {
                continue
            }
            
            var perpendicular = CGPoint(x: -direction.y, y: direction.x)
            let length = perpendicular.length
            if length > 0.0 {
                perpendicular = CGPoint(
                    x: perpendicular.x / length,
                    y: perpendicular.y / length
                )
            }
            
            let a = CGPoint(
                x: previousPoint.x + perpendicular.x * previousWidth / 2.0,
                y: previousPoint.y + perpendicular.y * previousWidth / 2.0
            )
            let b = CGPoint(
                x: previousPoint.x - perpendicular.x * previousWidth / 2.0,
                y: previousPoint.y - perpendicular.y * previousWidth / 2.0
            )
            let c = CGPoint(
                x: currentPoint.x + perpendicular.x * currentWidth / 2.0,
                y: currentPoint.y + perpendicular.y * currentWidth / 2.0
            )
            let d = CGPoint(
                x: currentPoint.x - perpendicular.x * currentWidth / 2.0,
                y: currentPoint.y - perpendicular.y * currentWidth / 2.0
            )
            
            let abCenter = CGPoint(
                x: (a.x + b.x) / 2.0,
                y: (a.y + b.y) / 2.0
            )
            let abRadius = CGPoint(
                x: abCenter.x - b.x,
                y: abCenter.y - b.y
            )
            let ab = CGPoint(
                x: abCenter.x - abRadius.y,
                y: abCenter.y + abRadius.x
            )
            
            let cdCenter = CGPoint(
                x: (c.x + d.x) / 2.0,
                y: (c.y + d.y) / 2.0
            )
            let cdRadius = CGPoint(
                x: cdCenter.x - c.x,
                y: cdCenter.y - c.y
            )
            let cd = CGPoint(
                x: cdCenter.x - cdRadius.y,
                y: cdCenter.y + cdRadius.x
            )
                        
            let minX = min(a.x, b.x, c.x, d.x, ab.x, cd.x)
            let minY = min(a.y, b.y, c.y, d.y, ab.y, cd.y)
            let maxX = max(a.x, b.x, c.x, d.x, ab.x, cd.x)
            let maxY = max(a.y, b.y, c.y, d.y, ab.y, cd.y)
            
            let segmentRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            updateRect = updateRect.union(segmentRect)

            let segment = Segment(a: a, b: b, c: c, d: d, radius1: previousWidth / 2.0, radius2: currentWidth / 2.0, rect: segmentRect)
            segments.append(segment)
        }
        return (segments, !updateRect.isNull ? updateRect : nil)
    }
    
    private var segmentPaths: [Int: CGPath] = [:]
    
    private func pathForSegment(_ segment: Segment) -> CGPath {
        let path = CGMutablePath()
        path.move(to: segment.b)
        
        let abStartAngle = atan2(
            segment.b.y - segment.a.y,
            segment.b.x - segment.a.x
        )
        path.addArc(
            center: CGPoint(
                x: (segment.a.x + segment.b.x) / 2,
                y: (segment.a.y + segment.b.y) / 2
            ),
            radius: segment.radius1,
            startAngle: abStartAngle,
            endAngle: abStartAngle + .pi,
            clockwise: true
        )
        path.addLine(to: segment.c)
        
        let cdStartAngle = atan2(
            segment.c.y - segment.d.y,
            segment.c.x - segment.d.x
        )
        path.addArc(
            center: CGPoint(
                x: (segment.c.x + segment.d.x) / 2,
                y: (segment.c.y + segment.d.y) / 2
            ),
            radius: segment.radius2,
            startAngle: cdStartAngle,
            endAngle: cdStartAngle + .pi,
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
    
    private func drawSegments(in context: CGContext, from: Int, to: Int) {
        context.setFillColor(self.renderColor.cgColor)
        
        for i in from ..< to {
            let segment = self.segments[i]
            
            var segmentPath: CGPath
            if let current = self.segmentPaths[i] {
                segmentPath = current
            } else {
                let path = self.pathForSegment(segment)
                self.segmentPaths[i] = path
                segmentPath = path
            }
            
            context.addPath(segmentPath)
            context.fillPath()
        }
    }
}

