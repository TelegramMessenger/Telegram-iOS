import Foundation
import UIKit
import QuartzCore
import simd
import MediaEditor

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

func normalizeDrawingRect(_ rect: CGRect, drawingSize: CGSize) -> CGRect {
    var rect = rect
    if rect.origin.x < 0.0 {
        rect.size.width += rect.origin.x
        rect.origin.x = 0.0
    }
    if rect.origin.y < 0.0 {
        rect.size.height += rect.origin.y
        rect.origin.y = 0.0
    }
    if rect.maxX > drawingSize.width {
        rect.size.width -= (rect.maxX - drawingSize.width)
    }
    if rect.maxY > drawingSize.height {
        rect.size.height -= (rect.maxY - drawingSize.height)
    }
    return rect
}

extension CATransform3D {
    func decompose() -> (translation: SIMD3<Float>, rotation: SIMD3<Float>, scale: SIMD3<Float>) {
        let m0 = SIMD3<Float>(Float(self.m11), Float(self.m12), Float(self.m13))
        let m1 = SIMD3<Float>(Float(self.m21), Float(self.m22), Float(self.m23))
        let m2 = SIMD3<Float>(Float(self.m31), Float(self.m32), Float(self.m33))
        let m3 = SIMD3<Float>(Float(self.m41), Float(self.m42), Float(self.m43))

        let t = m3

        let sx = length(m0)
        let sy = length(m1)
        let sz = length(m2)
        let s = SIMD3<Float>(sx, sy, sz)

        let rx = m0 / sx
        let ry = m1 / sy
        let rz = m2 / sz

        let pitch = atan2(ry.z, rz.z)
        let yaw = atan2(-rx.z, hypot(ry.z, rz.z))
        let roll = atan2(rx.y, rx.x)
        let r = SIMD3<Float>(pitch, yaw, roll)

        return (t, r, s)
    }
}
