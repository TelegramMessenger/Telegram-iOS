import Foundation
import UIKit
import simd

public let mediaEditorCropMaximumPerspectiveAngle: CGFloat = 30.0

private let mediaEditorPerspectiveFocalFactor: Double = 0.57

public struct MediaEditorCropPerspective: Codable, Equatable {
    public var vertical: CGFloat
    public var horizontal: CGFloat

    public init(vertical: CGFloat, horizontal: CGFloat) {
        self.vertical = vertical
        self.horizontal = horizontal
    }

    public static let zero = MediaEditorCropPerspective(vertical: 0.0, horizontal: 0.0)

    public var isZero: Bool {
        return abs(self.vertical) < CGFloat(Float.ulpOfOne) && abs(self.horizontal) < CGFloat(Float.ulpOfOne)
    }
}

public struct MediaEditorPerspectiveHomography: Equatable {
    public var m: simd_double3x3

    public init(m: simd_double3x3) {
        self.m = m
    }

    public static let identity = MediaEditorPerspectiveHomography(m: matrix_identity_double3x3)

    public init(perspective: MediaEditorCropPerspective, size: CGSize) {
        guard !perspective.isZero, size.width > 0.0, size.height > 0.0 else {
            self.m = matrix_identity_double3x3
            return
        }
        let a = Double(perspective.vertical)
        let b = Double(perspective.horizontal)
        let f = mediaEditorPerspectiveFocalFactor * Double(max(size.width, size.height))
        let r1 = simd_double3(cos(b), 0.0, -sin(b))
        let r2 = simd_double3(-sin(a) * sin(b), cos(a), -sin(a) * cos(b))
        let projection = MediaEditorPerspectiveHomography(m: simd_double3x3(rows: [
            simd_double3(r1.x, r2.x, 0.0),
            simd_double3(r1.y, r2.y, 0.0),
            simd_double3(r1.z / f, r2.z / f, 1.0)
        ]))
        let originalArea = Double(size.width * size.height)
        let warpedArea = mediaEditorPerspectiveQuadArea(projection.quad(size: size))
        let s = warpedArea > 0.0 ? sqrt(originalArea / warpedArea) : 1.0
        self.m = simd_double3x3(diagonal: simd_double3(s, s, 1.0)) * projection.m
    }

    public func apply(_ point: CGPoint) -> CGPoint {
        let v = self.m * simd_double3(Double(point.x), Double(point.y), 1.0)
        return CGPoint(x: v.x / v.z, y: v.y / v.z)
    }

    public var inverse: MediaEditorPerspectiveHomography {
        return MediaEditorPerspectiveHomography(m: self.m.inverse)
    }

    public func quad(size: CGSize) -> [CGPoint] {
        let halfWidth = size.width / 2.0
        let halfHeight = size.height / 2.0
        return [
            self.apply(CGPoint(x: -halfWidth, y: -halfHeight)),
            self.apply(CGPoint(x: halfWidth, y: -halfHeight)),
            self.apply(CGPoint(x: halfWidth, y: halfHeight)),
            self.apply(CGPoint(x: -halfWidth, y: halfHeight))
        ]
    }

    public func transform3D() -> CATransform3D {
        let m = self.m
        var transform = CATransform3DIdentity
        transform.m11 = CGFloat(m[0, 0])
        transform.m21 = CGFloat(m[1, 0])
        transform.m41 = CGFloat(m[2, 0])
        transform.m12 = CGFloat(m[0, 1])
        transform.m22 = CGFloat(m[1, 1])
        transform.m42 = CGFloat(m[2, 1])
        transform.m14 = CGFloat(m[0, 2])
        transform.m24 = CGFloat(m[1, 2])
        transform.m44 = CGFloat(m[2, 2])
        return transform
    }
}

private func mediaEditorPerspectiveQuadArea(_ quad: [CGPoint]) -> Double {
    var area: Double = 0.0
    for index in 0 ..< quad.count {
        let a = quad[index]
        let b = quad[(index + 1) % quad.count]
        area += Double(a.x * b.y - b.x * a.y)
    }
    return abs(area) / 2.0
}

public func mediaEditorCropContentQuad(originalSize: CGSize, rotation: CGFloat, perspective: MediaEditorCropPerspective) -> [CGPoint] {
    let rotatedSize = CGRect(origin: .zero, size: originalSize).applying(CGAffineTransform(rotationAngle: rotation)).size
    let cosine = cos(rotation)
    let sine = sin(rotation)
    return MediaEditorPerspectiveHomography(perspective: perspective, size: originalSize).quad(size: originalSize).map { point in
        CGPoint(x: point.x * cosine - point.y * sine + rotatedSize.width / 2.0, y: point.x * sine + point.y * cosine + rotatedSize.height / 2.0)
    }
}

public func mediaEditorCropRectFits(_ rect: CGRect, originalSize: CGSize, rotation: CGFloat, perspective: MediaEditorCropPerspective) -> Bool {
    let quad = mediaEditorCropContentQuad(originalSize: originalSize, rotation: rotation, perspective: perspective)
    var area: CGFloat = 0.0
    for index in 0 ..< quad.count {
        let a = quad[index]
        let b = quad[(index + 1) % quad.count]
        area += a.x * b.y - b.x * a.y
    }
    let sign: CGFloat = area < 0.0 ? -1.0 : 1.0
    let tolerance = max(originalSize.width, originalSize.height) * 1e-6
    let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
    for index in 0 ..< quad.count {
        let a = quad[index]
        let b = quad[(index + 1) % quad.count]
        let length = hypot(b.x - a.x, b.y - a.y)
        guard length > 0.0 else {
            continue
        }
        for corner in corners {
            let cross = ((b.x - a.x) * (corner.y - a.y) - (b.y - a.y) * (corner.x - a.x)) * sign
            if cross / length < -tolerance {
                return false
            }
        }
    }
    return true
}

public func mediaEditorCropRectFitted(_ rect: CGRect, originalSize: CGSize, rotation: CGFloat, perspective: MediaEditorCropPerspective) -> CGRect {
    if mediaEditorCropRectFits(rect, originalSize: originalSize, rotation: rotation, perspective: perspective) {
        return rect
    }
    func scaled(_ factor: CGFloat) -> CGRect {
        let size = CGSize(width: rect.width * factor, height: rect.height * factor)
        return CGRect(x: rect.midX - size.width / 2.0, y: rect.midY - size.height / 2.0, width: size.width, height: size.height)
    }
    var low: CGFloat = 0.0
    var high: CGFloat = 1.0
    for _ in 0 ..< 50 {
        let middle = (low + high) / 2.0
        if mediaEditorCropRectFits(scaled(middle), originalSize: originalSize, rotation: rotation, perspective: perspective) {
            low = middle
        } else {
            high = middle
        }
    }
    return scaled(low)
}
