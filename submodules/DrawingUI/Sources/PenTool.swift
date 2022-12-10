import Foundation
import UIKit
import Display

struct PointWeighted {
    let point: CGPoint
    let weight: CGFloat
    
    static let zero = PointWeighted(point: CGPoint.zero, weight: 0)
}

struct LineSegment {
    let start: CGPoint
    let end: CGPoint

    var length: CGFloat {
        return start.distance(to: end)
    }

    func average(with line: LineSegment) -> LineSegment {
        return LineSegment(start: start.average(with: line.start), end: end.average(with: line.end))
    }

    func normalLine(from weightedPoint: PointWeighted) -> LineSegment {
        return normalLine(withMiddle: weightedPoint.point, weight: weightedPoint.weight)
    }

    func normalLine(withMiddle middle: CGPoint, weight: CGFloat) -> LineSegment {
        let relativeEnd = start.diff(to: end)

        guard weight != 0 && relativeEnd != CGPoint.zero else {
            return LineSegment(start: middle, end: middle)
        }

        let moddle = weight / 2
        let lengthK = moddle / length

        let k = CGPoint(x: relativeEnd.x * lengthK, y: relativeEnd.y * lengthK)

        var normalLineStart = CGPoint(x: k.y, y: -k.x)
        var normalLineEnd = CGPoint(x: -k.y, y: k.x)

        normalLineStart.x += middle.x;
        normalLineStart.y += middle.y;

        normalLineEnd.x += middle.x;
        normalLineEnd.y += middle.y;

        return LineSegment(start: normalLineStart, end: normalLineEnd)
    }
}


extension CGPoint {
    func average(with point: CGPoint) -> CGPoint {
        return CGPoint(x: (x + point.x) * 0.5, y: (y + point.y) * 0.5)
    }
    
    func diff(to point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x - x, y: point.y - y)
    }
    
    func forward(to point: CGPoint, by: CGFloat) -> CGPoint {
        let diff = diff(to: point)
        let distance = sqrt(pow(diff.x, 2) + pow(diff.y, 2))
        let k = by / distance

        return CGPoint(x: point.x + diff.x * k, y: point.y + diff.y * k)
    }
}

final class PenTool: DrawingElement {
    class RenderLayer: SimpleLayer, DrawingRenderLayer {
        func setup(size: CGSize) {
            self.shouldRasterize = true
            self.contentsScale = 1.0
            
            let bounds = CGRect(origin: .zero, size: size)
            self.frame = bounds
        }
        
        private var paths: [UIBezierPath] = []
        private var tempPath: UIBezierPath?
        
        private var color: UIColor?
        fileprivate func draw(paths: [UIBezierPath], tempPath: UIBezierPath?, color: UIColor, rect: CGRect) {
            self.paths = paths
            self.tempPath = tempPath
            self.color = color
            
            self.setNeedsDisplay(rect.insetBy(dx: -50.0, dy: -50.0))
        }
        
        override func draw(in ctx: CGContext) {
            guard let color = self.color else {
                return
            }
            
            ctx.setFillColor(color.cgColor)
            
            for path in self.paths {
                ctx.addPath(path.cgPath)
                ctx.fillPath()
            }
            
            if let tempPath = self.tempPath {
                ctx.addPath(tempPath.cgPath)
                ctx.fillPath()
            }
        }
    }
    
    let uuid = UUID()
    
    let drawingSize: CGSize
    let color: DrawingColor
    let lineWidth: CGFloat
    let arrow: Bool
    
    var path: Polyline?
    var boundingBox: CGRect?
    
    var didSetupArrow = false
    let renderLineWidth: CGFloat
    
    var bezierPaths: [UIBezierPath] = []
    var tempBezierPath: UIBezierPath?
    
    var translation = CGPoint()
    
    private var currentRenderLayer: DrawingRenderLayer?
    
    var bounds: CGRect {
        return self.path?.bounds.offsetBy(dx: self.translation.x, dy: self.translation.y) ?? .zero
    }
    
    var _points: [Polyline.Point] = []
    
    var points: [Polyline.Point] {
        var points: [Polyline.Point] = []
        for point in self._points {
            points.append(point.offsetBy(self.translation))
        }
        return points
    }
    
    private let pointsPerLine: Int = 4
    private var nextPointIndex: Int = 0
    private var drawPoints = [PointWeighted](repeating: PointWeighted.zero, count: 4)
    
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
        
        let minLineWidth = max(1.0, min(drawingSize.width, drawingSize.height) * 0.003)
        let maxLineWidth = max(10.0, min(drawingSize.width, drawingSize.height) * 0.09)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        self.renderLineWidth = lineWidth
        
//        self.renderLine = StrokeLine(color: color.toUIColor(), minLineWidth: minLineWidth, lineWidth: lineWidth)
//        if arrow {
//            self.renderLineArrow1 = StrokeLine(color: color.toUIColor(), minLineWidth: minLineWidth, lineWidth: lineWidth * 0.8)
//            self.renderLineArrow2 = StrokeLine(color: color.toUIColor(), minLineWidth: minLineWidth, lineWidth: lineWidth * 0.8)
//        }
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        let layer = RenderLayer()
        layer.setup(size: self.drawingSize)
        self.currentRenderLayer = layer
        return layer
    }
    
    func updateWithLocation(_ point: CGPoint, ended: Bool = false) {
        if ended {
            if let path = tempBezierPath {
                bezierPaths.last?.append(path)
            }
            tempBezierPath = nil
            nextPointIndex = 0
        } else {
            addPoint(point)
        }
    }
    
    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
        guard case let .location(point) = path else {
            return
        }
                
        self._points.append(point)
        
        switch state {
        case .began:
            addPoint(point.location)
        case .changed:
            if self._points.count > 1 {
                self.updateTouchPoints(point: self._points[self._points.count - 1].location, previousPoint: self._points[self._points.count - 2].location)
                self.updateWithLocation(point.location)
            }
        case .ended:
            self.updateWithLocation(point.location, ended: true)
        case .cancelled:
            break
        }
        
        if let currentRenderLayer = self.currentRenderLayer as? RenderLayer {
            currentRenderLayer.draw(paths: self.bezierPaths, tempPath: self.tempBezierPath, color: self.color.toUIColor(), rect: CGRect(origin: .zero, size: self.drawingSize))
        }
        
//        self.path = line
//
//        let rect = self.renderLine.draw(at: point)
//        if let currentRenderLayer = self.currentRenderLayer as? RenderLayer {
//            currentRenderLayer.draw(line: self.renderLine, rect: rect)
//        }
        //        self.path = bezierPath
        
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
        
        //        let cgPath = bezierPath.path.cgPath.copy(strokingWithWidth: self.renderLineWidth, lineCap: .round, lineJoin: .round, miterLimit: 0.0)
        //        self.renderPath = cgPath
        
        //        if let currentRenderLayer = self.currentRenderLayer as? RenderLayer {
        //            currentRenderLayer.updatePath(cgPath)
        //        }
    }
    
    private let minDistance: CGFloat = 2
    
    private func addPoint(_ point: CGPoint) {
        if isFirstPoint {
            startNewLine(from: PointWeighted(point: point, weight: 2.0))
        } else {
            let previousPoint = self.drawPoints[nextPointIndex - 1].point
            guard previousPoint.distance(to: point) >= minDistance else {
                return
            }
            if isStartOfNextLine {
                finalizeBezier(nextLineStartPoint: point)
                startNewLine(from: self.drawPoints[3])
            }

            let weightedPoint = PointWeighted(point: point, weight: weightForLine(between: previousPoint, and: point))
            addPoint(point: weightedPoint)
        }

        let newBezier = generateBezierPath(withPointIndex: nextPointIndex - 1)
        self.tempBezierPath = newBezier
    }


    private var isFirstPoint: Bool {
        return nextPointIndex == 0
    }

    private var isStartOfNextLine: Bool {
        return nextPointIndex >= pointsPerLine
    }

    private func startNewLine(from weightedPoint: PointWeighted) {
        drawPoints[0] = weightedPoint
        nextPointIndex = 1
    }

    private func addPoint(point: PointWeighted) {
        drawPoints[nextPointIndex] = point
        nextPointIndex += 1
    }

    private func finalizeBezier(nextLineStartPoint: CGPoint) {
        let touchPoint2 = drawPoints[2].point
        let newTouchPoint3 = touchPoint2.average(with: nextLineStartPoint)
        drawPoints[3] = PointWeighted(point: newTouchPoint3, weight: weightForLine(between: touchPoint2, and: newTouchPoint3))

        guard let bezier = generateBezierPath(withPointIndex: 3) else {
            return
        }
        self.bezierPaths.append(bezier)
        
    }

    private func generateBezierPath(withPointIndex index: Int) -> UIBezierPath? {
        switch index {
        case 0:
            return UIBezierPath.dot(with: drawPoints[0])
        case 1:
            return UIBezierPath.curve(withPointA: drawPoints[0], pointB: drawPoints[1])
        case 2:
            return UIBezierPath.curve(withPointA: drawPoints[0], pointB: drawPoints[1], pointC: drawPoints[2])
        case 3:
            return UIBezierPath.curve(withPointA: drawPoints[0], pointB: drawPoints[1], pointC: drawPoints[2], pointD: drawPoints[3])
        default:
            return nil
        }
    }

    private func weightForLine(between pointA: CGPoint, and pointB: CGPoint) -> CGFloat {
        let length = pointA.distance(to: pointB)

        let limitRange: CGFloat = 50

        var lowerer: CGFloat = 0.2
        var constant: CGFloat = 2

        let toolWidth = self.renderLineWidth
        
        constant = toolWidth - 3.0
        lowerer = 0.25 * toolWidth / 10.0
        

        let r = min(limitRange, length)

//        var r = limitRange - length
//        if r < 0 {
//            r = 0
//        }

//        print(r * lowerer)

        return (r * lowerer) + constant
    }

    public  var firstPoint: CGPoint = .zero
    public  var currentPoint: CGPoint = .zero
    private var previousPoint: CGPoint = .zero
    private var previousPreviousPoint: CGPoint = .zero

    private func setTouchPoints(point: CGPoint, previousPoint: CGPoint) {
        self.previousPoint = previousPoint
        self.previousPreviousPoint = previousPoint
        self.currentPoint = point
    }

    private func updateTouchPoints(point: CGPoint, previousPoint: CGPoint) {
        self.previousPreviousPoint = self.previousPoint
        self.previousPoint = previousPoint
        self.currentPoint = point
    }

    private func calculateMidPoint(_ p1 : CGPoint, p2 : CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) * 0.5, y: (p1.y + p2.y) * 0.5);
    }

    private func getMidPoints() -> (CGPoint,  CGPoint) {
        let mid1 : CGPoint = calculateMidPoint(previousPoint, p2: previousPreviousPoint)
        let mid2 : CGPoint = calculateMidPoint(currentPoint, p2: previousPoint)
        return (mid1, mid2)
    }
    
    func draw(in context: CGContext, size: CGSize) {
        context.saveGState()
        
        context.translateBy(x: self.translation.x, y: self.translation.y)
        
        context.setShouldAntialias(true)

        context.setFillColor(self.color.toCGColor())
        for path in self.bezierPaths {
            context.addPath(path.cgPath)
            context.fillPath()
        }
        
        context.restoreGState()
    }
}

extension UIBezierPath {
    
    class func dot(with weightedPoint: PointWeighted) -> UIBezierPath {
        let path = UIBezierPath()
        path.addArc(withCenter: weightedPoint.point, radius: weightedPoint.weight / 2.0, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
        
        return path
    }

    class func curve(withPointA pointA: PointWeighted, pointB: PointWeighted) -> UIBezierPath {
        let lines = normalToLine(from: pointA, to: pointB)
        
        let path = UIBezierPath()
        path.move(to: lines.0.start)
        path.addLine(to: lines.1.start)
        let arcA = lines.1.start
        let arcB = lines.1.end
        path.addQuadCurve(to: arcB, controlPoint: pointA.point.forward(to: pointB.point, by: arcA.distance(to: arcB) / 1.1))
        path.addLine(to: lines.0.end)
        path.close()

        return path
    }
    
    class func curve(withPointA pointA: PointWeighted, pointB: PointWeighted, pointC: PointWeighted) -> UIBezierPath {
        let linesAB = normalToLine(from: pointA, to: pointB)
        let linesBC = normalToLine(from: pointB, to: pointC)
        
        let lineA = linesAB.0
        let lineB = linesAB.1.average(with: linesBC.0)
        let lineC = linesBC.1
        
        let path = UIBezierPath()
        path.move(to: lineA.start)
        path.addQuadCurve(to: lineC.start, controlPoint: lineB.start)
        let arcA = lineC.start
        let arcB = lineC.end

        path.addQuadCurve(to: arcB, controlPoint: pointB.point.forward(to: pointC.point, by: arcA.distance(to: arcB) / 1.1))
        path.addQuadCurve(to: lineA.end, controlPoint: lineB.end)
        path.close()
        
        return path
    }

    class func line(withPointA pointA: PointWeighted, pointB: PointWeighted, pointC: PointWeighted, prevLineSegment: LineSegment, roundedEnd: Bool = true) -> (UIBezierPath, LineSegment) {
        let linesAB = normalToLine(from: pointA, to: pointB)
        let linesBC = normalToLine(from: pointB, to: pointC)

//        let lineA = linesAB.0
        let lineB = linesAB.1.average(with: linesBC.0)
        let lineC = linesBC.1

        let path = UIBezierPath()
        path.move(to: prevLineSegment.start)
        path.addQuadCurve(to: lineC.start, controlPoint: lineB.start)
        if roundedEnd {
            let arcA = lineC.start
            let arcB = lineC.end

            path.addQuadCurve(to: arcB, controlPoint: pointB.point.forward(to: pointC.point, by: arcA.distance(to: arcB) / 1.1))
        } else {
            path.addLine(to: lineC.end)
        }
        path.addQuadCurve(to: prevLineSegment.end, controlPoint: lineB.end)
        path.close()

        return (path, lineC)
    }
    
    class func curve(withPointA pointA: PointWeighted, pointB: PointWeighted, pointC: PointWeighted, pointD: PointWeighted) -> UIBezierPath {
        let linesAB = normalToLine(from: pointA, to: pointB)
        let linesBC = normalToLine(from: pointB, to: pointC)
        let linesCD = normalToLine(from: pointC, to: pointD)
        
        let lineA = linesAB.0
        let lineB = linesAB.1.average(with: linesBC.0)
        let lineC = linesBC.1.average(with: linesCD.0)
        let lineD = linesCD.1
        
        let path = UIBezierPath()
        path.move(to: lineA.start)
        path.addCurve(to: lineD.start, controlPoint1: lineB.start, controlPoint2: lineC.start)
        let arcA = lineD.start
        let arcB = lineD.end
        path.addQuadCurve(to: arcB, controlPoint: pointC.point.forward(to: pointD.point, by: arcA.distance(to: arcB) / 1.1))
        path.addCurve(to: lineA.end, controlPoint1: lineC.end, controlPoint2: lineB.end)
        path.close()
        
        return path
    }
    
    class func normalToLine(from pointA: PointWeighted, to pointB: PointWeighted) -> (LineSegment, LineSegment) {
        let line = LineSegment(start: pointA.point, end: pointB.point)
        
        return (line.normalLine(from: pointA), line.normalLine(from: pointB))
    }
}



//
//final class PenTool: DrawingElement {
//    class RenderLayer: SimpleLayer, DrawingRenderLayer {
//        func setup(size: CGSize) {
//            self.shouldRasterize = true
//            self.contentsScale = 1.0
//
//            let bounds = CGRect(origin: .zero, size: size)
//            self.frame = bounds
//        }
//
//        private var line: StrokeLine?
//        fileprivate func draw(line: StrokeLine, rect: CGRect) {
//            self.line = line
//            self.setNeedsDisplay(rect.insetBy(dx: -50.0, dy: -50.0))
//        }
//
//        override func draw(in ctx: CGContext) {
//            self.line?.drawInContext(ctx)
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
//    var path: Polyline?
//    var boundingBox: CGRect?
//
//    private var renderLine: StrokeLine
//    var didSetupArrow = false
//    private var renderLineArrow1: StrokeLine?
//    private var renderLineArrow2: StrokeLine?
//    let renderLineWidth: CGFloat
//
//    var translation = CGPoint()
//
//    private var currentRenderLayer: DrawingRenderLayer?
//
//    var bounds: CGRect {
//        return self.path?.bounds.offsetBy(dx: self.translation.x, dy: self.translation.y) ?? .zero
//    }
//
//    var points: [Polyline.Point] {
//        guard let linePath = self.path else {
//            return []
//        }
//        var points: [Polyline.Point] = []
//        for point in linePath.points {
//            points.append(point.offsetBy(self.translation))
//        }
//        return points
//    }
//
//    func containsPoint(_ point: CGPoint) -> Bool {
//        return false
//        //        return self.renderPath?.contains(point.offsetBy(CGPoint(x: -self.translation.x, y: -self.translation.y))) ?? false
//    }
//
//    func hasPointsInsidePath(_ path: UIBezierPath) -> Bool {
//        if let linePath = self.path {
//            let pathBoundingBox = path.bounds
//            if self.bounds.intersects(pathBoundingBox) {
//                for point in linePath.points {
//                    if path.contains(point.location.offsetBy(self.translation)) {
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
//        let minLineWidth = max(1.0, min(drawingSize.width, drawingSize.height) * 0.003)
//        let maxLineWidth = max(10.0, min(drawingSize.width, drawingSize.height) * 0.09)
//        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
//
//        self.renderLineWidth = lineWidth
//
//        self.renderLine = StrokeLine(color: color.toUIColor(), minLineWidth: minLineWidth, lineWidth: lineWidth)
//        if arrow {
//            self.renderLineArrow1 = StrokeLine(color: color.toUIColor(), minLineWidth: minLineWidth, lineWidth: lineWidth * 0.8)
//            self.renderLineArrow2 = StrokeLine(color: color.toUIColor(), minLineWidth: minLineWidth, lineWidth: lineWidth * 0.8)
//        }
//    }
//
//    func setupRenderLayer() -> DrawingRenderLayer? {
//        let layer = RenderLayer()
//        layer.setup(size: self.drawingSize)
//        self.currentRenderLayer = layer
//        return layer
//    }
//
//    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
//        guard case let .polyline(line) = path, let point = line.points.last else {
//            return
//        }
//        self.path = line
//
//        let rect = self.renderLine.draw(at: point)
//        if let currentRenderLayer = self.currentRenderLayer as? RenderLayer {
//            currentRenderLayer.draw(line: self.renderLine, rect: rect)
//        }
//        //        self.path = bezierPath
//
//        //        if self.arrow && polyline.isComplete, polyline.points.count > 2 {
//        //            let lastPoint = lastPosition
//        //            var secondPoint = polyline.points[polyline.points.count - 2]
//        //            if secondPoint.location.distance(to: lastPoint) < self.renderArrowLineWidth {
//        //                secondPoint = polyline.points[polyline.points.count - 3]
//        //            }
//        //            let angle = lastPoint.angle(to: secondPoint.location)
//        //            let point1 = lastPoint.pointAt(distance: self.renderArrowLength, angle: angle - CGFloat.pi * 0.15)
//        //            let point2 = lastPoint.pointAt(distance: self.renderArrowLength, angle: angle + CGFloat.pi * 0.15)
//        //
//        //            let arrowPath = UIBezierPath()
//        //            arrowPath.move(to: point2)
//        //            arrowPath.addLine(to: lastPoint)
//        //            arrowPath.addLine(to: point1)
//        //            let arrowThickPath = arrowPath.cgPath.copy(strokingWithWidth: self.renderArrowLineWidth, lineCap: .round, lineJoin: .round, miterLimit: 0.0)
//        //
//        //            combinedPath.usesEvenOddFillRule = false
//        //            combinedPath.append(UIBezierPath(cgPath: arrowThickPath))
//        //        }
//
//        //        let cgPath = bezierPath.path.cgPath.copy(strokingWithWidth: self.renderLineWidth, lineCap: .round, lineJoin: .round, miterLimit: 0.0)
//        //        self.renderPath = cgPath
//
//        //        if let currentRenderLayer = self.currentRenderLayer as? RenderLayer {
//        //            currentRenderLayer.updatePath(cgPath)
//        //        }
//    }
//
//    func draw(in context: CGContext, size: CGSize) {
//        context.saveGState()
//
//        context.translateBy(x: self.translation.x, y: self.translation.y)
//
//        context.setShouldAntialias(true)
//
//        if self.arrow, let path = self.path, let lastPoint = path.points.last {
//            var lastPointWithVelocity: Polyline.Point?
//            for point in path.points.reversed() {
//                if point.velocity > 0.0 {
//                    lastPointWithVelocity = point
//                    break
//                }
//            }
//            if !self.didSetupArrow, let lastPointWithVelocity = lastPointWithVelocity {
//                let w = self.renderLineWidth
//                var dist: CGFloat = 18.0 * sqrt(w)
//                let spread: CGFloat = .pi * max(0.05, 0.03 * sqrt(w))
//
//                let suffix = path.points.suffix(100).reversed()
//
//                var p0 = suffix.first!
//
//                var p2 = suffix.last!
//                var d: CGFloat = 0
//                for p in suffix {
//                    d += hypot(p0.location.x - p.location.x, p0.location.y - p.location.y)
//                    if d >= dist {
//                        p2 = p
//                        break
//                    }
//                    p0 = p
//                }
//
//                p0 = suffix.first!
//                dist = min(dist, hypot(p0.location.x - p2.location.x, p0.location.y - p2.location.y))
//
//                var i = 0
//                for spread in [-spread, spread] {
//                    var points: [CGPoint] = []
//                    points.append(lastPoint.location)
//
//                    p0 = suffix.first!
//                    var prev = p0.location
//                    d = 0
//                    for p in suffix {
//                        let d1 = hypot(p0.location.x - p.location.x, p0.location.y - p.location.y)
//                        d += d1
//                        if d >= dist {
//                            break
//                        }
//                        let d2 = d1 / cos(spread)
//                        let angle = atan2(p.location.y - p0.location.y, p.location.x - p0.location.x)
//                        let cur = CGPoint(x: prev.x + d2 * cos(angle + spread), y: prev.y + d2 * sin(angle + spread))
//
//                        points.append(
//                            cur
//                        )
//
//                        p0 = p
//                        prev = cur
//                    }
//
//                    for point in points {
//                        if i == 0 {
//                            let _ = self.renderLineArrow1?.draw(at: Polyline.Point(location: point, force: 0.0, altitudeAngle: 0.0, azimuth: 0.0, velocity: lastPointWithVelocity.velocity, touchPoint: lastPointWithVelocity.touchPoint))
//                        } else if i == 1 {
//                            let _ = self.renderLineArrow2?.draw(at: Polyline.Point(location: point, force: 0.0, altitudeAngle: 0.0, azimuth: 0.0, velocity: lastPointWithVelocity.velocity, touchPoint: lastPointWithVelocity.touchPoint))
//                        }
//                    }
//                    i += 1
//                }
//                self.didSetupArrow = true
//            }
//            self.renderLineArrow1?.drawInContext(context)
//            self.renderLineArrow2?.drawInContext(context)
//        }
//
//        self.renderLine.drawInContext(context)
//
//        context.restoreGState()
//    }
//}
//
//private class StrokeLine {
//    struct Segment {
//        let a: CGPoint
//        let b: CGPoint
//        let c: CGPoint
//        let d: CGPoint
//        let abWidth: CGFloat
//        let cdWidth: CGFloat
//    }
//
//    struct Point {
//        let position: CGPoint
//        let width: CGFloat
//
//        init(position: CGPoint, width: CGFloat) {
//            self.position = position
//            self.width = width
//        }
//    }
//
//    private(set) var points: [Point] = []
//    private var smoothPoints: [Point] = []
//    private var segments: [Segment] = []
//    private var lastWidth: CGFloat?
//
//    private let minLineWidth: CGFloat
//    let lineWidth: CGFloat
//
//    let color: UIColor
//
//    init(color: UIColor, minLineWidth: CGFloat, lineWidth: CGFloat) {
//        self.color = color
//        self.minLineWidth = minLineWidth
//        self.lineWidth = lineWidth
//    }
//
//    func draw(at point: Polyline.Point) -> CGRect {
//        let width = extractLineWidth(from: point.velocity)
//        self.lastWidth = width
//
//        let point = Point(position: point.location, width: width)
//        return appendPoint(point)
//    }
//
//    func drawInContext(_ context: CGContext) {
//        self.drawSegments(self.segments, inContext: context)
//    }
//
//    func extractLineWidth(from velocity: CGFloat) -> CGFloat {
//        let minValue = self.minLineWidth
//        let maxValue = self.lineWidth
//
//        var size = max(minValue, min(maxValue + 1 - (velocity / 150), maxValue))
//        if let lastWidth = self.lastWidth {
//            size = size * 0.2 + lastWidth * 0.8
//        }
//        return size
//    }
//
//    func appendPoint(_ point: Point) -> CGRect {
//        self.points.append(point)
//
//        guard self.points.count > 2 else { return .null }
//
//        let index = self.points.count - 1
//        let point0 = self.points[index - 2]
//        let point1 = self.points[index - 1]
//        let point2 = self.points[index]
//
//        let newSmoothPoints = smoothPoints(
//            fromPoint0: point0,
//            point1: point1,
//            point2: point2
//        )
//
//        let lastOldSmoothPoint = smoothPoints.last
//        smoothPoints.append(contentsOf: newSmoothPoints)
//
//        guard smoothPoints.count > 1 else { return .null }
//
//        let newSegments: ([Segment], CGRect) = {
//            guard let lastOldSmoothPoint = lastOldSmoothPoint else {
//                return segments(fromSmoothPoints: newSmoothPoints)
//            }
//            return segments(fromSmoothPoints: [lastOldSmoothPoint] + newSmoothPoints)
//        }()
//        segments.append(contentsOf: newSegments.0)
//
//        return newSegments.1
//    }
//
//    func smoothPoints(fromPoint0 point0: Point, point1: Point, point2: Point) -> [Point] {
//        var smoothPoints = [Point]()
//
//        let midPoint1 = (point0.position + point1.position) * 0.5
//        let midPoint2 = (point1.position + point2.position) * 0.5
//
//        let segmentDistance = 2.0
//        let distance = midPoint1.distance(to: midPoint2)
//        let numberOfSegments = min(128, max(floor(distance/segmentDistance), 32))
//
//        let step = 1.0 / numberOfSegments
//        for t in stride(from: 0, to: 1, by: step) {
//            let position = midPoint1 * pow(1 - t, 2) + point1.position * 2 * (1 - t) * t + midPoint2 * t * t
//            let size = pow(1 - t, 2) * ((point0.width + point1.width) * 0.5) + 2 * (1 - t) * t * point1.width + t * t * ((point1.width + point2.width) * 0.5)
//            let point = Point(position: position, width: size)
//            smoothPoints.append(point)
//        }
//
//        let finalPoint = Point(position: midPoint2, width: (point1.width + point2.width) * 0.5)
//        smoothPoints.append(finalPoint)
//
//        return smoothPoints
//    }
//
//    func segments(fromSmoothPoints smoothPoints: [Point]) -> ([Segment], CGRect) {
//        var segments = [Segment]()
//        var updateRect = CGRect.null
//        for i in 1 ..< smoothPoints.count {
//            let previousPoint = smoothPoints[i - 1].position
//            let previousWidth = smoothPoints[i - 1].width
//            let currentPoint = smoothPoints[i].position
//            let currentWidth = smoothPoints[i].width
//            let direction = currentPoint - previousPoint
//
//            guard !currentPoint.isEqual(to: previousPoint, epsilon: 0.0001) else {
//                continue
//            }
//
//            var perpendicular = CGPoint(x: -direction.y, y: direction.x)
//            let length = perpendicular.length
//            if length > 0.0 {
//                perpendicular = perpendicular / length
//            }
//
//            let a = previousPoint + perpendicular * previousWidth / 2
//            let b = previousPoint - perpendicular * previousWidth / 2
//            let c = currentPoint + perpendicular * currentWidth / 2
//            let d = currentPoint - perpendicular * currentWidth / 2
//
//            let ab: CGPoint = {
//                let center = (b + a)/2
//                let radius = center - b
//                return .init(x: center.x - radius.y, y: center.y + radius.x)
//            }()
//            let cd: CGPoint = {
//                let center = (c + d)/2
//                let radius = center - c
//                return .init(x: center.x + radius.y, y: center.y - radius.x)
//            }()
//
//            let minX = min(a.x, b.x, c.x, d.x, ab.x, cd.x)
//            let minY = min(a.y, b.y, c.y, d.y, ab.y, cd.y)
//            let maxX = max(a.x, b.x, c.x, d.x, ab.x, cd.x)
//            let maxY = max(a.y, b.y, c.y, d.y, ab.y, cd.y)
//
//            updateRect = updateRect.union(CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
//
//            segments.append(Segment(a: a, b: b, c: c, d: d, abWidth: previousWidth, cdWidth: currentWidth))
//        }
//        return (segments, updateRect)
//    }
//
//    func drawSegments(_ segments: [Segment], inContext context: CGContext) {
//        for segment in segments {
//            context.beginPath()
//
//            context.setStrokeColor(color.cgColor)
//            context.setFillColor(color.cgColor)
//
//            context.move(to: segment.b)
//
//            let abStartAngle = atan2(segment.b.y - segment.a.y, segment.b.x - segment.a.x)
//            context.addArc(
//                center: (segment.a + segment.b)/2,
//                radius: segment.abWidth/2,
//                startAngle: abStartAngle,
//                endAngle: abStartAngle + .pi,
//                clockwise: true
//            )
//            context.addLine(to: segment.c)
//
//            let cdStartAngle = atan2(segment.c.y - segment.d.y, segment.c.x - segment.d.x)
//            context.addArc(
//                center: (segment.c + segment.d)/2,
//                radius: segment.cdWidth/2,
//                startAngle: cdStartAngle,
//                endAngle: cdStartAngle + .pi,
//                clockwise: true
//            )
//            context.closePath()
//
//            context.fillPath()
//            context.strokePath()
//        }
//    }
//}
//
