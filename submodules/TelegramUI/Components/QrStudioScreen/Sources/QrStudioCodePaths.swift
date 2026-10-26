import Foundation
import CoreGraphics
import QrCode

private func addRoundedRect(_ path: CGMutablePath, rect: CGRect, topLeft: CGFloat, topRight: CGFloat, bottomRight: CGFloat, bottomLeft: CGFloat) {
    path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
    if topRight > 0.0 {
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + topRight), radius: topRight)
    }
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
    if bottomRight > 0.0 {
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY), radius: bottomRight)
    }
    path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
    if bottomLeft > 0.0 {
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft), radius: bottomLeft)
    }
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
    if topLeft > 0.0 {
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + topLeft, y: rect.minY), radius: topLeft)
    }
    path.closeSubpath()
}

struct QrStudioCodePaths {
    let body: CGPath
    let frames: CGPath
    let balls: CGPath
    let logoDiameter: CGFloat

    static func logoRadius(size: Int) -> CGFloat {
        return CGFloat(size) * 0.135
    }

    static func eyeParts(rect outer: CGRect, unit: CGFloat) -> (outer: CGPath, inner: CGPath, ball: CGPath) {
        let inner = outer.insetBy(dx: unit, dy: unit)
        let ball = outer.insetBy(dx: unit * 2.0, dy: unit * 2.0)
        let outerRadius = unit * 7.0 * 0.3
        let innerRadius = unit * 5.0 * 0.24
        let ballRadius = unit * 3.0 * 0.3
        return (
            CGPath(roundedRect: outer, cornerWidth: outerRadius, cornerHeight: outerRadius, transform: nil),
            CGPath(roundedRect: inner, cornerWidth: innerRadius, cornerHeight: innerRadius, transform: nil),
            CGPath(roundedRect: ball, cornerWidth: ballRadius, cornerHeight: ballRadius, transform: nil)
        )
    }

    static func isInLogo(x: Int, y: Int, size: Int) -> Bool {
        let center = CGFloat(size - 1) / 2.0
        return hypot(CGFloat(x) - center, CGFloat(y) - center) < self.logoRadius(size: size) + 0.5
    }

    init(matrix: QrCodeMatrix, side: CGFloat) {
        let size = matrix.size
        let unit = side / CGFloat(max(size, 1))

        func dark(_ x: Int, _ y: Int) -> Bool {
            guard x >= 0, y >= 0, x < size, y < size else {
                return false
            }
            // Not `matrix.isEye(x:y:)`: with that inlined, Swift 6.4's SimplifyCFG crashes on this
            // init at -Osize ("cannot get borrow introducers for unknown guaranteed value").
            if QrCodeMatrix.isEye(x: x, y: y, size: size) || QrStudioCodePaths.isInLogo(x: x, y: y, size: size) {
                return false
            }
            return matrix[x, y]
        }

        let body = CGMutablePath()
        let convex = unit / 3.0
        let concave = unit / 4.0
        for y in 0 ..< size {
            for x in 0 ..< size {
                let originX = CGFloat(x) * unit
                let originY = CGFloat(y) * unit
                if dark(x, y) {
                    let left = dark(x - 1, y)
                    let right = dark(x + 1, y)
                    let top = dark(x, y - 1)
                    let bottom = dark(x, y + 1)
                    addRoundedRect(
                        body,
                        rect: CGRect(x: originX, y: originY, width: unit, height: unit),
                        topLeft: (left || top) ? 0.0 : convex,
                        topRight: (right || top) ? 0.0 : convex,
                        bottomRight: (right || bottom) ? 0.0 : convex,
                        bottomLeft: (left || bottom) ? 0.0 : convex
                    )
                } else {
                    for (dx, dy) in [(-1, -1), (1, -1), (1, 1), (-1, 1)] where dark(x + dx, y) && dark(x, y + dy) && dark(x + dx, y + dy) {
                        let cornerX = dx < 0 ? originX : originX + unit
                        let cornerY = dy < 0 ? originY : originY + unit
                        let stepX = CGFloat(-dx) * concave
                        let stepY = CGFloat(-dy) * concave
                        body.move(to: CGPoint(x: cornerX, y: cornerY))
                        body.addLine(to: CGPoint(x: cornerX + stepX, y: cornerY))
                        body.addQuadCurve(to: CGPoint(x: cornerX, y: cornerY + stepY), control: CGPoint(x: cornerX, y: cornerY))
                        body.closeSubpath()
                    }
                }
            }
        }

        let frames = CGMutablePath()
        let balls = CGMutablePath()
        if size >= 21 {
            for eye in matrix.eyes {
                let parts = QrStudioCodePaths.eyeParts(rect: CGRect(x: CGFloat(eye.x) * unit, y: CGFloat(eye.y) * unit, width: unit * 7.0, height: unit * 7.0), unit: unit)
                frames.addPath(parts.outer)
                frames.addPath(parts.inner)
                balls.addPath(parts.ball)
            }
        }

        self.body = body
        self.frames = frames
        self.balls = balls
        self.logoDiameter = size > 0 ? side * (QrStudioCodePaths.logoRadius(size: size) * 2.0 - 1.3) / CGFloat(size) : 0.0
    }
}

enum QrStudioCardMetrics {
    static let width: CGFloat = 300.0
    static let cornerRadius: CGFloat = 40.0
    static let codeSide: CGFloat = 200.0
    static let pillReserve: CGFloat = 40.0
    static let groupShift: CGFloat = -9.5

    static func height(showsUsername: Bool) -> CGFloat {
        return 50.0 + 200.0 + (showsUsername ? 39.0 + 30.0 : 50.0)
    }

    static func cardCenterY(screenHeight: CGFloat, showsUsername: Bool) -> CGFloat {
        let cardHeight = self.height(showsUsername: showsUsername)
        let group = cardHeight + self.pillReserve
        return screenHeight / 2.0 + self.groupShift - group / 2.0 + cardHeight / 2.0
    }
}
