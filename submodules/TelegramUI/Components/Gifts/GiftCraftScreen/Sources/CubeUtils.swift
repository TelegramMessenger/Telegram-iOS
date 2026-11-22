import UIKit
import simd

func normalize2(_ v: SIMD2<Float>) -> SIMD2<Float> {
    let l = simd_length(v)
    return l > 1e-5 ? v / l : SIMD2<Float>(0, 0)
}

func normalizedRotation(_ r: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3<Float>(normalizeAngle(r.x), normalizeAngle(r.y), normalizeAngle(r.z))
}

struct ProjectedFace {
    let quad: Quad
    let rotation: CGFloat
}

struct Quad {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomLeft: CGPoint
    var bottomRight: CGPoint

    init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    init(rect: CGRect) {
        self.init(
            topLeft: rect.origin,
            topRight: CGPoint(x: rect.maxX, y: rect.minY),
            bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
            bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
        )
    }

    func boundingBox() -> CGRect {
        let xs = [topLeft.x, topRight.x, bottomLeft.x, bottomRight.x]
        let ys = [topLeft.y, topRight.y, bottomLeft.y, bottomRight.y]
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return .zero
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    func offsetting(dx: CGFloat, dy: CGFloat) -> Quad {
        return Quad(
            topLeft: CGPoint(x: topLeft.x + dx, y: topLeft.y + dy),
            topRight: CGPoint(x: topRight.x + dx, y: topRight.y + dy),
            bottomLeft: CGPoint(x: bottomLeft.x + dx, y: bottomLeft.y + dy),
            bottomRight: CGPoint(x: bottomRight.x + dx, y: bottomRight.y + dy)
        )
    }

    func interpolated(to other: Quad, t: CGFloat) -> Quad {
        return Quad(
            topLeft: lerp(topLeft, other.topLeft, t),
            topRight: lerp(topRight, other.topRight, t),
            bottomLeft: lerp(bottomLeft, other.bottomLeft, t),
            bottomRight: lerp(bottomRight, other.bottomRight, t)
        )
    }

    func apply(to view: UIView) {
        let bounds = boundingBox()
        let localQuad = offsetting(dx: -bounds.origin.x, dy: -bounds.origin.y)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        view.frame = bounds
        let transform = rectToQuad(rect: view.bounds, quad: localQuad)
        view.layer.transform = transform
        CATransaction.commit()
    }
}

func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    return a + (b - a) * t
}

func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    return CGPoint(x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t))
}

func normalizeAngle(_ angle: CGFloat) -> CGFloat {
    var result = angle
    let twoPi = CGFloat.pi * 2
    while result > CGFloat.pi {
        result -= twoPi
    }
    while result <= -CGFloat.pi {
        result += twoPi
    }
    return result
}

func normalizeAngle(_ angle: Float) -> Float {
    var result = angle
    let twoPi = Float.pi * 2
    while result > Float.pi {
        result -= twoPi
    }
    while result <= -Float.pi {
        result += twoPi
    }
    return result
}

func normalizeAnglePositive(_ angle: Float) -> Float {
    var result = angle
    let twoPi = Float.pi * 2
    while result < 0 { result += twoPi }
    while result >= twoPi { result -= twoPi }
    return result
}

func shortestAngleDelta(from: Float, to: Float) -> Float {
    return normalizeAngle(to - from)
}

func nonZeroSign(_ value: Float, fallback: Float) -> Float {
    if value > 0 { return 1 }
    if value < 0 { return -1 }
    return fallback
}

func snappedRightAngle(_ angle: CGFloat) -> CGFloat {
    let quarter = CGFloat.pi / 2
    let normalized = normalizeAngle(angle)
    let step = round(normalized / quarter)
    return step * quarter
}

func rectToQuad(rect: CGRect, quad: Quad) -> CATransform3D {
    let x1a = quad.topLeft.x
    let y1a = quad.topLeft.y
    let x2a = quad.topRight.x
    let y2a = quad.topRight.y
    let x3a = quad.bottomLeft.x
    let y3a = quad.bottomLeft.y
    let x4a = quad.bottomRight.x
    let y4a = quad.bottomRight.y

    let X = rect.origin.x
    let Y = rect.origin.y
    let W = rect.size.width
    let H = rect.size.height

    let y21 = y2a - y1a
    let y32 = y3a - y2a
    let y43 = y4a - y3a
    let y14 = y1a - y4a
    let y31 = y3a - y1a
    let y42 = y4a - y2a

    let a = -H * (x2a * x3a * y14 + x2a * x4a * y31 - x1a * x4a * y32 + x1a * x3a * y42)
    let b = W * (x2a * x3a * y14 + x3a * x4a * y21 + x1a * x4a * y32 + x1a * x2a * y43)
    let c = H * X * (x2a * x3a * y14 + x2a * x4a * y31 - x1a * x4a * y32 + x1a * x3a * y42)
        - H * W * x1a * (x4a * y32 - x3a * y42 + x2a * y43)
        - W * Y * (x2a * x3a * y14 + x3a * x4a * y21 + x1a * x4a * y32 + x1a * x2a * y43)

    let d = H * (-x4a * y21 * y3a + x2a * y1a * y43 - x1a * y2a * y43 - x3a * y1a * y4a + x3a * y2a * y4a)
    let e = W * (x4a * y2a * y31 - x3a * y1a * y42 - x2a * y31 * y4a + x1a * y3a * y42)
    let f = -(
        W * (x4a * (Y * y2a * y31 + H * y1a * y32)
             - x3a * (H + Y) * y1a * y42
             + H * x2a * y1a * y43
             + x2a * Y * (y1a - y3a) * y4a
             + x1a * Y * y3a * (-y2a + y4a))
        - H * X * (x4a * y21 * y3a - x2a * y1a * y43 + x3a * (y1a - y2a) * y4a + x1a * y2a * (-y3a + y4a))
    )

    let g = H * (x3a * y21 - x4a * y21 + (-x1a + x2a) * y43)
    let h = W * (-x2a * y31 + x4a * y31 + (x1a - x3a) * y42)
    var i = W * Y * (x2a * y31 - x4a * y31 - x1a * y42 + x3a * y42)
        + H * (X * (-(x3a * y21) + x4a * y21 + x1a * y43 - x2a * y43)
               + W * (-(x3a * y2a) + x4a * y2a + x2a * y3a - x4a * y3a - x2a * y4a + x3a * y4a))

    let epsilon: CGFloat = 0.0001
    if abs(i) < epsilon {
        i = i >= 0 ? epsilon : -epsilon
    }

    return CATransform3D(
        m11: a / i, m12: d / i, m13: 0, m14: g / i,
        m21: b / i, m22: e / i, m23: 0, m24: h / i,
        m31: 0,     m32: 0,     m33: 1, m34: 0,
        m41: c / i, m42: f / i, m43: 0, m44: 1
    )
}
