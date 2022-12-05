import Foundation
import UIKit
import QuartzCore
import simd

struct DrawingColor: Equatable {
    public static var clear = DrawingColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat
    public var alpha: CGFloat
    
    public var position: CGPoint?
    
    var isClear: Bool {
        return self.red.isZero && self.green.isZero && self.blue.isZero && self.alpha.isZero
    }
    
    public init(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat = 1.0,
        position: CGPoint? = nil
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.position = position
    }
    
    public init(color: UIColor) {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 1.0
        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        } else if color.getWhite(&red, alpha: &alpha) {
            self.init(red: red, green: red, blue: red, alpha: alpha)
        } else {
            self.init(red: 0.0, green: 0.0, blue: 0.0)
        }
    }
    
    public init(rgb: UInt32) {
        self.init(color: UIColor(rgb: rgb))
    }
 
    func withUpdatedRed(_ red: CGFloat) -> DrawingColor {
        return DrawingColor(
            red: red,
            green: self.green,
            blue: self.blue,
            alpha: self.alpha
        )
    }
    
    func withUpdatedGreen(_ green: CGFloat) -> DrawingColor {
        return DrawingColor(
            red: self.red,
            green: green,
            blue: self.blue,
            alpha: self.alpha
        )
    }
    
    func withUpdatedBlue(_ blue: CGFloat) -> DrawingColor {
        return DrawingColor(
            red: self.red,
            green: self.green,
            blue: blue,
            alpha: self.alpha
        )
    }
    
    func withUpdatedAlpha(_ alpha: CGFloat) -> DrawingColor {
        return DrawingColor(
            red: self.red,
            green: self.green,
            blue: self.blue,
            alpha: alpha,
            position: self.position
        )
    }
    
    func withUpdatedPosition(_ position: CGPoint) -> DrawingColor {
        return DrawingColor(
            red: self.red,
            green: self.green,
            blue: self.blue,
            alpha: self.alpha,
            position: position
        )
    }
    
    func toUIColor() -> UIColor {
        return UIColor(
            red: self.red,
            green: self.green,
            blue: self.blue,
            alpha: self.alpha
        )
    }
    
    func toCGColor() -> CGColor {
        return self.toUIColor().cgColor
    }
    
    func toFloat4() -> vector_float4 {
        return [
            simd_float1(self.red),
            simd_float1(self.green),
            simd_float1(self.blue),
            simd_float1(self.alpha)
        ]
    }
    
    public static func ==(lhs: DrawingColor, rhs: DrawingColor) -> Bool {
        if lhs.red != rhs.red {
            return false
        }
        if lhs.green != rhs.green {
            return false
        }
        if lhs.blue != rhs.blue {
            return false
        }
        if lhs.alpha != rhs.alpha {
            return false
        }
        return true
    }
}

extension UIBezierPath {
    convenience init(roundRect rect: CGRect, topLeftRadius: CGFloat = 0.0, topRightRadius: CGFloat = 0.0, bottomLeftRadius: CGFloat = 0.0, bottomRightRadius: CGFloat = 0.0) {
        self.init()

        let path = CGMutablePath()

        let topLeft = rect.origin
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)

        if topLeftRadius != .zero {
            path.move(to: CGPoint(x: topLeft.x+topLeftRadius, y: topLeft.y))
        } else {
            path.move(to: CGPoint(x: topLeft.x, y: topLeft.y))
        }

        if topRightRadius != .zero {
            path.addLine(to: CGPoint(x: topRight.x-topRightRadius, y: topRight.y))
            path.addCurve(to:  CGPoint(x: topRight.x, y: topRight.y+topRightRadius), control1: CGPoint(x: topRight.x, y: topRight.y), control2:CGPoint(x: topRight.x, y: topRight.y + topRightRadius))
        } else {
             path.addLine(to: CGPoint(x: topRight.x, y: topRight.y))
        }

        if bottomRightRadius != .zero {
            path.addLine(to: CGPoint(x: bottomRight.x, y: bottomRight.y-bottomRightRadius))
            path.addCurve(to: CGPoint(x: bottomRight.x-bottomRightRadius, y: bottomRight.y), control1: CGPoint(x: bottomRight.x, y: bottomRight.y), control2: CGPoint(x: bottomRight.x-bottomRightRadius, y: bottomRight.y))
        } else {
            path.addLine(to: CGPoint(x: bottomRight.x, y: bottomRight.y))
        }

        if bottomLeftRadius != .zero {
            path.addLine(to: CGPoint(x: bottomLeft.x+bottomLeftRadius, y: bottomLeft.y))
            path.addCurve(to: CGPoint(x: bottomLeft.x, y: bottomLeft.y-bottomLeftRadius), control1: CGPoint(x: bottomLeft.x, y: bottomLeft.y), control2: CGPoint(x: bottomLeft.x, y: bottomLeft.y-bottomLeftRadius))
        } else {
            path.addLine(to: CGPoint(x: bottomLeft.x, y: bottomLeft.y))
        }

        if topLeftRadius != .zero {
            path.addLine(to: CGPoint(x: topLeft.x, y: topLeft.y+topLeftRadius))
            path.addCurve(to: CGPoint(x: topLeft.x+topLeftRadius, y: topLeft.y) , control1: CGPoint(x: topLeft.x, y: topLeft.y) , control2: CGPoint(x: topLeft.x+topLeftRadius, y: topLeft.y))
        } else {
            path.addLine(to: CGPoint(x: topLeft.x, y: topLeft.y))
        }

        path.closeSubpath()
        self.cgPath = path
    }
}

extension CGPoint {
    func isEqual(to point: CGPoint, epsilon: CGFloat) -> Bool {
        if x - epsilon <= point.x && point.x <= x + epsilon && y - epsilon <= point.y && point.y <= y + epsilon {
            return true
        }
        return false
    }
    
    static public func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static public func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static public func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    
    static public func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }
    
    var length: CGFloat {
        return sqrt(self.x * self.x + self.y * self.y)
    }
    
    static func middle(p1: CGPoint, p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) * 0.5, y: (p1.y + p2.y) * 0.5)
    }
    
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow((point.x - self.x), 2) + pow((point.y - self.y), 2))
    }
    
    func distanceSquared(to point: CGPoint) -> CGFloat {
        return pow((point.x - self.x), 2) + pow((point.y - self.y), 2)
    }
    
    func angle(to point: CGPoint) -> CGFloat {
        return atan2((point.y - self.y), (point.x - self.x))
    }
    
    func pointAt(distance: CGFloat, angle: CGFloat) -> CGPoint {
        return CGPoint(x: distance * cos(angle) + self.x, y: distance * sin(angle) + self.y)
    }
    
    func point(to point: CGPoint, t: CGFloat) -> CGPoint {
        return CGPoint(x: self.x + t * (point.x - self.x), y: self.y + t * (point.y - self.y))
    }
    
    func perpendicularPointOnLine(start: CGPoint, end: CGPoint) -> CGPoint {
        let l2 = start.distanceSquared(to: end)
        if l2.isZero {
            return start
        }
        let t = ((self.x - start.x) * (end.x - start.x) + (self.y - start.y) * (end.y - start.y)) / l2
        return CGPoint(x: start.x + t * (end.x - start.x), y: start.y + t * (end.y - start.y))
    }
    
    func linearBezierPoint(to: CGPoint, t: CGFloat) -> CGPoint {
      let dx = to.x - x;
      let dy = to.y - y;
      
      let px = x + (t * dx);
      let py = y + (t * dy);
      
      return CGPoint(x: px, y: py)
    }
    
    fileprivate func _cubicBezier(_ t: CGFloat, _ start: CGFloat, _ c1: CGFloat, _ c2: CGFloat, _ end: CGFloat) -> CGFloat {
        let _t = 1 - t;
        let _t2 = _t * _t;
        let _t3 = _t * _t * _t ;
        let t2 = t * t;
        let t3 = t * t * t;
        
        return  _t3 * start +
        3.0 * _t2 * t * c1 +
        3.0 * _t * t2 * c2 +
        t3 * end;
    }
    
    func cubicBezierPoint(to: CGPoint, controlPoint1 c1: CGPoint, controlPoint2 c2: CGPoint, t: CGFloat) -> CGPoint {
        let x = _cubicBezier(t, self.x, c1.x, c2.x, to.x);
        let y = _cubicBezier(t, self.y, c1.y, c2.y, to.y);
        
        return CGPoint(x: x, y: y);
    }
    
    fileprivate func _quadBezier(_ t: CGFloat, _ start: CGFloat, _ c1: CGFloat, _ end: CGFloat) -> CGFloat {
        let _t = 1 - t;
        let _t2 = _t * _t;
        let t2 = t * t;
        
        return  _t2 * start +
        2 * _t * t * c1 +
        t2 * end;
    }
    
    func quadBezierPoint(to: CGPoint, controlPoint: CGPoint, t: CGFloat) -> CGPoint {
        let x = _quadBezier(t, self.x, controlPoint.x, to.x);
        let y = _quadBezier(t, self.y, controlPoint.y, to.y);
        
        return CGPoint(x: x, y: y);
    }
}


extension CGPath {
    static func star(in rect: CGRect, extrusion: CGFloat, points: Int = 5) -> CGPath {
        func pointFrom(angle: CGFloat, radius: CGFloat, offset: CGPoint) -> CGPoint {
            return CGPoint(x: radius * cos(angle) + offset.x, y: radius * sin(angle) + offset.y)
        }
        
        let path = CGMutablePath()

        let center = rect.center.offsetBy(dx: 0.0, dy: rect.height * 0.05)
        var angle: CGFloat = -CGFloat(.pi / 2.0)
        let angleIncrement = CGFloat(.pi * 2.0 / Double(points))
        let radius = rect.width / 2.0

        var firstPoint = true
        for _ in 1 ... points {
            let point = center.pointAt(distance: radius, angle: angle)
            let nextPoint = center.pointAt(distance: radius, angle: angle + angleIncrement)
            let midPoint = center.pointAt(distance: extrusion, angle: angle + angleIncrement * 0.5)

            if firstPoint {
                firstPoint = false
                path.move(to: point)
            }
            path.addLine(to: midPoint)
            path.addLine(to: nextPoint)

            angle += angleIncrement
        }
        path.closeSubpath()
        
        return path
    }
    
    static func arrow(from point: CGPoint, controlPoint: CGPoint, width: CGFloat, height: CGFloat, isOpen: Bool) -> CGPath {
        let angle = atan2(point.y - controlPoint.y, point.x - controlPoint.x)
        let angleAdjustment = atan2(width, -height)
        let distance = hypot(width, height)
        
        let path = CGMutablePath()
        path.move(to: point)
        path.addLine(to: point.pointAt(distance: distance, angle: angle - angleAdjustment))
        if isOpen {
            path.addLine(to: point)
        }
        path.addLine(to: point.pointAt(distance: distance, angle: angle + angleAdjustment))
        if isOpen {
            path.addLine(to: point)
        } else {
            path.closeSubpath()
        }
        return path
    }
    
    static func curve(start: CGPoint, end: CGPoint, mid: CGPoint, lineWidth: CGFloat?, arrowSize: CGSize?, twoSided: Bool = false) -> CGPath {
        let linePath = CGMutablePath()
                
        let controlPoints = configureControlPoints(data: [start, mid, end])
        var lineStart = start
        if let arrowSize = arrowSize, twoSided {
            lineStart = start.pointAt(distance: -arrowSize.height * 0.5, angle: controlPoints[0].ctrl1.angle(to: start))
        }
        linePath.move(to: lineStart)
        linePath.addCurve(to: mid, control1: controlPoints[0].ctrl1, control2: controlPoints[0].ctrl2)
        
        var lineEnd = end
        if let arrowSize = arrowSize {
            lineEnd = end.pointAt(distance: -arrowSize.height * 0.5, angle: controlPoints[1].ctrl1.angle(to: end))
        }
        linePath.addCurve(to: lineEnd, control1: controlPoints[1].ctrl1, control2: controlPoints[1].ctrl2)
        
        let path: CGMutablePath
        if let lineWidth = lineWidth, let mutablePath = linePath.copy(strokingWithWidth: lineWidth, lineCap: .square, lineJoin: .round, miterLimit: 0.0).mutableCopy() {
            path = mutablePath
        } else {
            path = linePath
        }
        
        if let arrowSize = arrowSize {
            let arrowPath = arrow(from: end, controlPoint: controlPoints[1].ctrl1, width: arrowSize.width, height: arrowSize.height, isOpen: false)
            path.addPath(arrowPath)
            
            if twoSided {
                let secondArrowPath = arrow(from: start, controlPoint: controlPoints[0].ctrl1, width: arrowSize.width, height: arrowSize.height, isOpen: false)
                path.addPath(secondArrowPath)
            }
        }
    
        return path
    }
    
    static func bubble(in rect: CGRect, cornerRadius: CGFloat, smallCornerRadius: CGFloat, tailPosition: CGPoint, tailWidth: CGFloat) -> CGPath {
        let r1 = min(cornerRadius, min(rect.width, rect.height) / 3.0)
        let r2 = min(smallCornerRadius, min(rect.width, rect.height) / 10.0)
        
        let ax = tailPosition.x * rect.width
        let ay = tailPosition.y
        
        let width = min(max(tailWidth, ay / 2.0), rect.width / 4.0)
        let angle = atan2(ay, width)
        let h = r2 / tan(angle / 2.0)
        
        let r1a = min(r1, min(rect.maxX - ax, ax - rect.minX) * 0.5)
        let r2a = min(r2, min(rect.maxX - ax, ax - rect.minX) * 0.2)
        
        let path = CGMutablePath()
        path.addArc(center: CGPoint(x: rect.minX + r1, y: rect.minY + r1), radius: r1, startAngle: .pi, endAngle: .pi * 3.0 / 2.0, clockwise: false)
        path.addArc(center: CGPoint(x: rect.maxX - r1, y: rect.minY + r1), radius: r1, startAngle: -.pi / 2.0, endAngle: 0.0, clockwise: false)
                        
        if ax > rect.width / 2.0 {
            if ax < rect.width - 1 {
                path.addArc(center: CGPoint(x: rect.maxX - r1a, y: rect.maxY - r1a), radius: r1a, startAngle: 0.0, endAngle: .pi / 2.0, clockwise: false)
                path.addArc(center: CGPoint(x: rect.minX + ax + r2a, y: rect.maxY + r2a), radius: r2a, startAngle: .pi * 3.0 / 2.0, endAngle: .pi, clockwise: true)
            }
            path.addLine(to: CGPoint(x: rect.minX + ax, y: rect.maxY + ay))
            path.addArc(center: CGPoint(x: rect.minX + ax - width - r2, y: rect.maxY + h), radius: h, startAngle: -(CGFloat.pi / 2 - angle), endAngle: CGFloat.pi * 3 / 2, clockwise: true)
            path.addArc(center: CGPoint(x: rect.minX + r1, y: rect.maxY - r1), radius: r1, startAngle: CGFloat.pi / 2, endAngle: CGFloat.pi, clockwise: false)
        } else {
            path.addArc(center: CGPoint(x: rect.maxX - r1, y: rect.maxY - r1), radius: r1, startAngle: 0, endAngle: CGFloat.pi / 2, clockwise: false)
            path.addArc(center: CGPoint(x: rect.minX + ax + width + r2, y: rect.maxY + h), radius: h, startAngle: CGFloat.pi * 3 / 2, endAngle: CGFloat.pi * 3 / 2 - angle, clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX + ax, y: rect.maxY + ay))
            if ax > 1 {
                path.addArc(center: CGPoint(x: rect.minX + ax - r2a, y: rect.maxY + r2a), radius: r2a, startAngle: 0, endAngle: CGFloat.pi * 3 / 2, clockwise: true)
                path.addArc(center: CGPoint(x: rect.minX + r1a, y: rect.maxY - r1a), radius: r1a, startAngle: CGFloat.pi / 2, endAngle: CGFloat.pi, clockwise: false)
            }
        }
        
        path.closeSubpath()
        
        return path
    }
}

private func configureControlPoints(data: [CGPoint]) -> [(ctrl1: CGPoint, ctrl2: CGPoint)] {
    let segments = data.count - 1
    
    if segments == 1 {
        let p0 = data[0]
        let p3 = data[1]
        
        return [(p0, p3)]
    } else if segments > 1 {
        var ad: [CGFloat] = []
        var d: [CGFloat] = []
        var bd: [CGFloat] = []
        
        var rhsArray: [CGPoint] = []
        
        for i in 0 ..< segments {
            var rhsXValue: CGFloat = 0.0
            var rhsYValue: CGFloat = 0.0
            
            let p0 = data[i]
            let p3 = data[i + 1]
            
            if i == 0 {
                bd.append(0.0)
                d.append(2.0)
                ad.append(1.0)
                
                rhsXValue = p0.x + 2.0 * p3.x
                rhsYValue = p0.y + 2.0 * p3.y
            } else if i == segments - 1 {
                bd.append(2.0)
                d.append(7.0)
                ad.append(0.0)
                
                rhsXValue = 8.0 * p0.x + p3.x
                rhsYValue = 8.0 * p0.y + p3.y
            } else {
                bd.append(1.0)
                d.append(4.0)
                ad.append(1.0)
                
                rhsXValue = 4.0 * p0.x + 2.0 * p3.x
                rhsYValue = 4.0 * p0.y + 2.0 * p3.y
            }
            
            rhsArray.append(CGPoint(x: rhsXValue, y: rhsYValue))
        }
        
        var firstControlPoints: [CGPoint?] = []
        var secondControlPoints: [CGPoint?] = []
        
        var controlPoints : [(CGPoint, CGPoint)] = []
        
        var solutionSet1 = [CGPoint?]()
        solutionSet1 = Array(repeating: nil, count: segments)
        
        ad[0] = ad[0] / d[0]
        rhsArray[0].x = rhsArray[0].x / d[0]
        rhsArray[0].y = rhsArray[0].y / d[0]
        
        if segments > 2 {
            for i in 1...segments - 2 {
                let rhsValueX = rhsArray[i].x
                let prevRhsValueX = rhsArray[i - 1].x
                
                let rhsValueY = rhsArray[i].y
                let prevRhsValueY = rhsArray[i - 1].y
                
                ad[i] = ad[i] / (d[i] - bd[i] * ad[i - 1]);
                
                let exp1x = (rhsValueX - (bd[i] * prevRhsValueX))
                let exp1y = (rhsValueY - (bd[i] * prevRhsValueY))
                let exp2 = (d[i] - bd[i] * ad[i - 1])
                
                rhsArray[i].x = exp1x / exp2
                rhsArray[i].y = exp1y / exp2
            }
        }
        
        let lastElementIndex = segments - 1
        let exp1 = (rhsArray[lastElementIndex].x - bd[lastElementIndex] * rhsArray[lastElementIndex - 1].x)
        let exp1y = (rhsArray[lastElementIndex].y - bd[lastElementIndex] * rhsArray[lastElementIndex - 1].y)
        let exp2 = (d[lastElementIndex] - bd[lastElementIndex] * ad[lastElementIndex - 1])
        rhsArray[lastElementIndex].x = exp1 / exp2
        rhsArray[lastElementIndex].y = exp1y / exp2
        
        solutionSet1[lastElementIndex] = rhsArray[lastElementIndex]
        
        for i in (0..<lastElementIndex).reversed() {
            let controlPointX = rhsArray[i].x - (ad[i] * solutionSet1[i + 1]!.x)
            let controlPointY = rhsArray[i].y - (ad[i] * solutionSet1[i + 1]!.y)
            
            solutionSet1[i] = CGPoint(x: controlPointX, y: controlPointY)
        }
        
        firstControlPoints = solutionSet1
        
        for i in (0..<segments) {
            if i == (segments - 1) {
                
                let lastDataPoint = data[i + 1]
                let p1 = firstControlPoints[i]
                guard let controlPoint1 = p1 else { continue }
                
                let controlPoint2X = 0.5 * (lastDataPoint.x + controlPoint1.x)
                let controlPoint2y = 0.5 * (lastDataPoint.y + controlPoint1.y)
                
                let controlPoint2 = CGPoint(x: controlPoint2X, y: controlPoint2y)
                secondControlPoints.append(controlPoint2)
            }else {
                
                let dataPoint = data[i+1]
                let p1 = firstControlPoints[i+1]
                guard let controlPoint1 = p1 else { continue }
                
                let controlPoint2X = 2*dataPoint.x - controlPoint1.x
                let controlPoint2Y = 2*dataPoint.y - controlPoint1.y
                
                secondControlPoints.append(CGPoint(x: controlPoint2X, y: controlPoint2Y))
            }
        }
        
        for i in (0..<segments) {
            guard let firstControlPoint = firstControlPoints[i] else { continue }
            guard let secondControlPoint = secondControlPoints[i] else { continue }
            
            controlPoints.append((firstControlPoint, secondControlPoint))
        }

        return controlPoints
    }
    return []
}





class FPSCounter: NSObject {

    /// Helper class that relays display link updates to the FPSCounter
    ///
    /// This is necessary because CADisplayLink retains its target. Thus
    /// if the FPSCounter class would be the target of the display link
    /// it would create a retain cycle. The delegate has a weak reference
    /// to its parent FPSCounter, thus preventing this.
    ///
    internal class DisplayLinkProxy: NSObject {

        /// A weak ref to the parent FPSCounter instance.
        @objc weak var parentCounter: FPSCounter?

        /// Notify the parent FPSCounter of a CADisplayLink update.
        ///
        /// This method is automatically called by the CADisplayLink.
        ///
        /// - Parameters:
        ///   - displayLink: The display link that updated
        ///
        @objc func updateFromDisplayLink(_ displayLink: CADisplayLink) {
            parentCounter?.updateFromDisplayLink(displayLink)
        }
    }


    // MARK: - Initialization

    private let displayLink: CADisplayLink
    private let displayLinkProxy: DisplayLinkProxy

    /// Create a new FPSCounter.
    ///
    /// To start receiving FPS updates you need to start tracking with the
    /// `startTracking(inRunLoop:mode:)` method.
    ///
    public override init() {
        self.displayLinkProxy = DisplayLinkProxy()
        self.displayLink = CADisplayLink(
            target: self.displayLinkProxy,
            selector: #selector(DisplayLinkProxy.updateFromDisplayLink(_:))
        )

        super.init()

        self.displayLinkProxy.parentCounter = self
    }

    deinit {
        self.displayLink.invalidate()
    }


    // MARK: - Configuration

    /// The delegate that should receive FPS updates.
    public weak var delegate: FPSCounterDelegate?

    /// Delay between FPS updates. Longer delays mean more averaged FPS numbers.
    @objc public var notificationDelay: TimeInterval = 1.0


    // MARK: - Tracking

    private var runloop: RunLoop?
    private var mode: RunLoop.Mode?

    /// Start tracking FPS updates.
    ///
    /// You can specify wich runloop to use for tracking, as well as the runloop modes.
    /// Usually you'll want the main runloop (default), and either the common run loop modes
    /// (default), or the tracking mode (`RunLoop.Mode.tracking`).
    ///
    /// When the counter is already tracking, it's stopped first.
    ///
    /// - Parameters:
    ///   - runloop: The runloop to start tracking in
    ///   - mode:    The mode(s) to track in the runloop
    ///
    @objc public func startTracking(inRunLoop runloop: RunLoop = .main, mode: RunLoop.Mode = .common) {
        self.stopTracking()

        self.runloop = runloop
        self.mode = mode
        self.displayLink.add(to: runloop, forMode: mode)
    }

    /// Stop tracking FPS updates.
    ///
    /// This method does nothing if the counter is not currently tracking.
    ///
    @objc public func stopTracking() {
        guard let runloop = self.runloop, let mode = self.mode else { return }

        self.displayLink.remove(from: runloop, forMode: mode)
        self.runloop = nil
        self.mode = nil
    }


    // MARK: - Handling Frame Updates

    private var lastNotificationTime: CFAbsoluteTime = 0.0
    private var numberOfFrames = 0

    private func updateFromDisplayLink(_ displayLink: CADisplayLink) {
        if self.lastNotificationTime == 0.0 {
            self.lastNotificationTime = CFAbsoluteTimeGetCurrent()
            return
        }

        self.numberOfFrames += 1

        let currentTime = CFAbsoluteTimeGetCurrent()
        let elapsedTime = currentTime - self.lastNotificationTime

        if elapsedTime >= self.notificationDelay {
            self.notifyUpdateForElapsedTime(elapsedTime)
            self.lastNotificationTime = 0.0
            self.numberOfFrames = 0
        }
    }

    private func notifyUpdateForElapsedTime(_ elapsedTime: CFAbsoluteTime) {
        let fps = Int(round(Double(self.numberOfFrames) / elapsedTime))
        self.delegate?.fpsCounter(self, didUpdateFramesPerSecond: fps)
    }
}


/// The delegate protocol for the FPSCounter class.
///
/// Implement this protocol if you want to receive updates from a `FPSCounter`.
///
protocol FPSCounterDelegate: NSObjectProtocol {

    /// Called in regular intervals while the counter is tracking FPS.
    ///
    /// - Parameters:
    ///   - counter: The FPSCounter that sent the update
    ///   - fps:     The current FPS of the application
    ///
    func fpsCounter(_ counter: FPSCounter, didUpdateFramesPerSecond fps: Int)
}

class BezierPath {
    struct Element {
        enum ElementType {
            case moveTo
            case addLine
            case cubicCurve
            case quadCurve
        }
        
        let type: ElementType
        
        var startPoint: Polyline.Point
        var endPoint: Polyline.Point
        var controlPoints: [CGPoint]
        
        var lengthRange: ClosedRange<CGFloat>?
        var calculatedLength: CGFloat?
                
        func point(at t: CGFloat) -> CGPoint {
            switch self.type {
            case .addLine:
                return self.startPoint.location.linearBezierPoint(to: self.endPoint.location, t: t)
            case .cubicCurve:
                return self.startPoint.location.cubicBezierPoint(to: self.endPoint.location, controlPoint1: self.controlPoints[0], controlPoint2: self.controlPoints[1], t: t)
            case .quadCurve:
                return self.startPoint.location.quadBezierPoint(to: self.endPoint.location, controlPoint: self.controlPoints[0], t: t)
            default:
                return .zero
            }
        }
    }
    
    let path = UIBezierPath()
    
    var elements: [Element] = []
    var elementCount: Int {
        return self.elements.count
    }
    
    func element(at t: CGFloat) -> (element: Element, innerT: CGFloat)? {
        let t = min(max(0.0, t), 1.0)
        
        for element in elements {
            if let lengthRange = element.lengthRange, lengthRange.contains(t) {
                let innerT = (t - lengthRange.lowerBound) / (lengthRange.upperBound - lengthRange.lowerBound)
                return (element, innerT)
            }
        }
        return nil
    }
    
    var points: [Int: CGPoint] = [:]
    func point(at t: CGFloat) -> CGPoint? {
        if let (element, innerT) = self.element(at: t) {
            return element.point(at: innerT)
        } else {
            return nil
        }
    }
    
    func append(_ element: Element) {
        self.elements.append(element)
        switch element.type {
        case .moveTo:
            self.move(to: element.startPoint.location)
        case .addLine:
            self.addLine(to: element.endPoint.location)
        case .cubicCurve:
            self.addCurve(to: element.endPoint.location, controlPoint1: element.controlPoints[0], controlPoint2: element.controlPoints[1])
        case .quadCurve:
            self.addQuadCurve(to: element.endPoint.location, controlPoint: element.controlPoints[0])
        }
    }
        
    private func move(to point: CGPoint) {
        self.path.move(to: point)
    }
    
    private func addLine(to point: CGPoint) {
        self.path.addLine(to: point)
    }
    
    private func addQuadCurve(to point: CGPoint, controlPoint: CGPoint) {
        self.path.addQuadCurve(to: point, controlPoint: controlPoint)
    }
    
    private func addCurve(to point: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint) {
        self.path.addCurve(to: point, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
    }
    
    private func close() {
        self.path.close()
    }
    
    func trimming(to elementIndex: Int) -> BezierPath {
        let outputPath = BezierPath()
        for element in self.elements[0 ... elementIndex] {
            outputPath.append(element)
        }
        return outputPath
    }
    
    func closedCopy() -> BezierPath {
        let outputPath = BezierPath()
        for element in self.elements {
            outputPath.append(element)
        }
        outputPath.close()
        return outputPath
    }
}

func concaveHullPath(points: [CGPoint]) -> CGPath {
    let hull = getHull(points, concavity: 1000.0)
    let hullPath = CGMutablePath()
    var moved = true
    for point in hull {
        if moved {
            hullPath.move(to: point)
            moved = false
        } else {
            hullPath.addLine(to: point)
        }
    }
    hullPath.closeSubpath()
    
    return hullPath
}

func expandPath(_ path: CGPath, width: CGFloat) -> CGPath {
    let expandedPath = path.copy(strokingWithWidth: width * 2.0, lineCap: .round, lineJoin: .round, miterLimit: 0.0)
    
    class UserInfo {
        let outputPath = CGMutablePath()
        var passedFirst = false
    }
    var userInfo = UserInfo()
    
    withUnsafeMutablePointer(to: &userInfo) { userInfoPointer in
        expandedPath.apply(info: userInfoPointer) { (userInfo, nextElementPointer) in
            let element = nextElementPointer.pointee
            let userInfoPointer = userInfo!.assumingMemoryBound(to: UserInfo.self)
            let userInfo = userInfoPointer.pointee
            
            if !userInfo.passedFirst {
                if case .closeSubpath = element.type {
                    userInfo.passedFirst = true
                }
            } else {
                switch element.type {
                case .moveToPoint:
                    userInfo.outputPath.move(to: element.points[0])
                case .addLineToPoint:
                    userInfo.outputPath.addLine(to: element.points[0])
                case .addQuadCurveToPoint:
                    userInfo.outputPath.addQuadCurve(to: element.points[1], control: element.points[0])
                case .addCurveToPoint:
                    userInfo.outputPath.addCurve(to: element.points[2], control1: element.points[0], control2: element.points[1])
                case .closeSubpath:
                    userInfo.outputPath.closeSubpath()
                @unknown default:
                    userInfo.outputPath.closeSubpath()
                }
            }
        }
    }
    return userInfo.outputPath
}

class Matrix {
    private(set) var m: [Float]
    
    private init() {
        m = [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        ]
    }
    
    @discardableResult
    func translation(x: Float, y: Float, z: Float) -> Matrix {
        m[12] = x
        m[13] = y
        m[14] = z
        return self
    }
    
    @discardableResult
    func scaling(x: Float, y: Float, z: Float) -> Matrix {
        m[0] = x
        m[5] = y
        m[10] = z
        return self
    }
    
    static var identity = Matrix()
}

struct Vertex {
    var position: vector_float4
    var texCoord: vector_float2
    
    init(position: CGPoint, texCoord: CGPoint) {
        self.position = position.toFloat4()
        self.texCoord = texCoord.toFloat2()
    }
}

struct Point {
    var position: vector_float4
    var color: vector_float4
    var angle: Float
    var size: Float

    init(x: CGFloat, y: CGFloat, color: DrawingColor, size: CGFloat, angle: CGFloat = 0) {
        self.position = vector_float4(Float(x), Float(y), 0, 1)
        self.size = Float(size)
        self.color = color.toFloat4()
        self.angle = Float(angle)
    }
}

extension CGPoint {
    func toFloat4(z: CGFloat = 0, w: CGFloat = 1) -> vector_float4 {
        return [Float(x), Float(y), Float(z) ,Float(w)]
    }
    
    func toFloat2() -> vector_float2 {
        return [Float(x), Float(y)]
    }
    
    func offsetBy(_ offset: CGPoint) -> CGPoint {
        return self.offsetBy(dx: offset.x, dy: offset.y)
    }
}
