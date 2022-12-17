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
    let renderArrowLength: CGFloat
    let renderArrowLineWidth: CGFloat
    
    var bezierPaths: [UIBezierPath] = []
    var tempBezierPath: UIBezierPath?
    
    var arrowLeftPath: UIBezierPath?
    var arrowLeftPoint: CGPoint?
    var arrowRightPath: UIBezierPath?
    var arrowRightPoint: CGPoint?
    
    var translation = CGPoint()
    
    private var currentRenderLayer: DrawingRenderLayer?
    
    var bounds: CGRect {
        return self.path?.bounds.offsetBy(dx: self.translation.x, dy: self.translation.y) ?? .zero
    }
    
    var _points: [Polyline.Point] = []
    
    var points: [Polyline.Point] {
        var points: [Polyline.Point] = []
        var lastPoint: Polyline.Point?
        for point in self._points {
            points.append(point.offsetBy(self.translation))
            lastPoint = point
        }
        if let arrowLeftPoint, let lastPoint {
            points.append(lastPoint.withLocation(arrowLeftPoint.offsetBy(self.translation)))
        }
        if let arrowRightPoint, let lastPoint {
            points.append(lastPoint.withLocation(arrowRightPoint.offsetBy(self.translation)))
        }
        return points
    }
    
    private let pointsPerLine: Int = 4
    private var nextPointIndex: Int = 0
    private var drawPoints = [PointWeighted](repeating: PointWeighted.zero, count: 4)
    
    private var arrowParams: (CGPoint, CGFloat)?
    
    func containsPoint(_ point: CGPoint) -> Bool {
        for path in self.bezierPaths {
            if path.contains(point.offsetBy(CGPoint(x: -self.translation.x, y: -self.translation.y))) {
                return true
            }
        }
        return false
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
        
        let minLineWidth = max(1.0, min(drawingSize.width, drawingSize.height) * 0.0015)
        let maxLineWidth = max(10.0, min(drawingSize.width, drawingSize.height) * 0.05)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        self.renderLineWidth = lineWidth
        self.renderArrowLength = lineWidth * 7.0
        self.renderArrowLineWidth = lineWidth * 2.0
        
        self.path = Polyline(points: [])
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
    
    var lastPoint: CGPoint?
    func updateWithLocation(_ point: CGPoint, ended: Bool = false) {
        if ended {
            self.lastPoint = self.drawPoints[self.nextPointIndex - 1].point
            
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
        self.path?.points.append(point)
        
        switch state {
        case .began:
            addPoint(point.location)
        case .changed:
            if self._points.count > 1 {
                self.updateTouchPoints(point: self._points[self._points.count - 1].location, previousPoint: self._points[self._points.count - 2].location)
                self.updateWithLocation(point.location)
            }
        case .ended:
            self.updateTouchPoints(point: self._points[self._points.count - 1].location, previousPoint: self._points[self._points.count - 2].location)
            self.updateWithLocation(point.location, ended: true)
            
            if self.arrow {
                let points = self.path?.points ?? []
                var direction: CGFloat?
                
                let p2 = points[points.count - 1].location
                for i in 1 ..< min(points.count - 2, 12) {
                    let p1 = points[points.count - 1 - i].location
                    if p1.distance(to: p2) > renderArrowLength * 0.5 {
                        direction = p2.angle(to: p1)
                        break
                    }
                }
                                
                if let point = self.lastPoint, let direction {
                    self.arrowParams = (point, direction)
                    
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
        case .cancelled:
            break
        }
        
        if let currentRenderLayer = self.currentRenderLayer as? RenderLayer {
            currentRenderLayer.draw(paths: self.bezierPaths, tempPath: self.tempBezierPath, color: self.color.toUIColor(), rect: CGRect(origin: .zero, size: self.drawingSize))
        }
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
