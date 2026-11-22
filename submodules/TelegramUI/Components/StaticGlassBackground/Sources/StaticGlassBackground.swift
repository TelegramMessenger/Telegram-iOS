import Foundation
import UIKit

public enum StaticGlassTint: Equatable {
    case panel
    /// A styled tint, with the alpha it lies over the glass at.
    case color(UIColor)
    /// The dark glass over media (tinted black at 0.3), the same in both themes: plates and controls over a picture.
    case media
}

public enum StaticGlassAssetShape: String {
    case capsuleR10 = "capsule-r10"
    case capsuleR15 = "capsule-r15"
    case capsuleR21 = "capsule-r21"
    case circleR15 = "circle-r15"
    case circleR24 = "circle-r24"
    case verticalCapsuleR15 = "vcapsule-r15"
    /// A rounded rectangle of radius 12 that stretches both ways.
    case rectR12 = "rect-r12"

    var shapeHeight: CGFloat {
        switch self {
        case .capsuleR10:
            return 20.0
        case .capsuleR15, .circleR15:
            return 30.0
        case .capsuleR21:
            return 42.0
        case .circleR24:
            return 48.0
        case .verticalCapsuleR15:
            return 60.0
        case .rectR12:
            return 80.0
        }
    }
}

public struct StaticGlassAssetChoice: Equatable {
    public var shape: StaticGlassAssetShape
    /// How much the asset is scaled to fit a height it was not captured at.
    public var scale: CGFloat

    public init(shape: StaticGlassAssetShape, scale: CGFloat) {
        self.shape = shape
        self.scale = scale
    }
}

/// The captured asset for a shape: capsules by height (20, 30 or 42, the nearest otherwise, scaled), a 30pt circle or,
/// above 36pt, a 48pt one, the 30pt-wide vertical capsule (scaled by width otherwise), and a rounded rectangle (a radius
/// below half the shorter side) from the r12 rectangle scaled to its radius. The dark glass over media (`isMedia`) has
/// only the rectangle, a 20pt capsule and a 48pt circle.
public func staticGlassAssetChoice(size: CGSize, cornerRadius: CGFloat, isMedia: Bool = false) -> StaticGlassAssetChoice {
    let isCircle = abs(size.width - size.height) <= 0.5
    if cornerRadius < min(size.width, size.height) * 0.5 - 0.5 {
        return StaticGlassAssetChoice(shape: .rectR12, scale: cornerRadius / 12.0)
    }
    if isMedia {
        if isCircle {
            return StaticGlassAssetChoice(shape: .circleR24, scale: size.height / 48.0)
        }
        return StaticGlassAssetChoice(shape: .capsuleR10, scale: size.height / 20.0)
    }
    if size.height > size.width + 0.5 {
        return StaticGlassAssetChoice(shape: .verticalCapsuleR15, scale: size.width / 30.0)
    }
    if isCircle {
        if size.height > 36.0 {
            return StaticGlassAssetChoice(shape: .circleR24, scale: size.height / 48.0)
        }
        return StaticGlassAssetChoice(shape: .circleR15, scale: size.height / 30.0)
    }
    let shape = [StaticGlassAssetShape.capsuleR10, .capsuleR15, .capsuleR21].min(by: { abs(size.height - $0.shapeHeight) < abs(size.height - $1.shapeHeight) })!
    return StaticGlassAssetChoice(shape: shape, scale: size.height / shape.shapeHeight)
}

/// The captured set for a tint the model does not reproduce (its assets are `static-glass-<shape>-<set>`): the monochrome
/// ink, black on light glass and white on dark, and white at 0.8 on light glass. Nil for any other tint.
public func staticGlassCapturedTint(color: UIColor, isDark: Bool) -> String? {
    var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
    guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else {
        return nil
    }
    func near(_ x: CGFloat, _ y: CGFloat) -> Bool {
        return abs(x - y) < 0.01
    }
    if !isDark && near(r, 0.0) && near(g, 0.0) && near(b, 0.0) && near(a, 1.0) {
        return "tint-000000a100-light"
    }
    if isDark && near(r, 1.0) && near(g, 1.0) && near(b, 1.0) && near(a, 1.0) {
        return "tint-FFFFFFa100-dark"
    }
    if !isDark && near(r, 1.0) && near(g, 1.0) && near(b, 1.0) && near(a, 0.8) {
        return "tint-FFFFFFa80-light"
    }
    return nil
}

/// Where a shape is shorter than its asset's ends along an axis the asset stretches on, the length (asset pixels at the
/// image's scale) it is cut to along that axis; nil where it stretches.
public func staticGlassCutLengths(size: CGSize, imageScale: CGFloat, assetFrame: CGRect, stretchesHorizontally: Bool, stretchesVertically: Bool, scale: Int) -> (width: Int?, height: Int?) {
    func cut(_ length: CGFloat, _ assetLength: CGFloat, _ stretches: Bool) -> Int? {
        guard stretches else {
            return nil
        }
        let lengthInAsset = length * imageScale
        guard staticGlassNeedsCutting(shapeWidth: lengthInAsset / CGFloat(scale), assetFrameWidth: Int(assetLength), scale: scale) else {
            return nil
        }
        return max(2, Int(lengthInAsset.rounded()))
    }
    return (cut(size.width, assetFrame.width, stretchesHorizontally), cut(size.height, assetFrame.height, stretchesVertically))
}

/// Whether a capsule is narrower than its asset's two ends (the asset frame less its 1pt middle): it is then cut from
/// the ends rather than stretched.
public func staticGlassNeedsCutting(shapeWidth: CGFloat, assetFrameWidth: Int, scale: Int) -> Bool {
    return shapeWidth * CGFloat(scale) < CGFloat(assetFrameWidth - scale) - 0.01
}

/// A premultiplied pixel with a styled tint laid over it where the shape covers it: as the glass does inside its shape,
/// the tint over what is there at the tint's alpha.
public func staticGlassTintedPixel(_ pixel: [UInt8], coverage: CGFloat, tint: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)) -> [UInt8] {
    let t = tint.a * coverage
    if t <= 0.0 {
        return pixel
    }
    let values = [tint.r, tint.g, tint.b]
    var result: [UInt8] = []
    for i in 0 ..< 3 {
        let f = CGFloat(pixel[i]) * (1.0 - t) + t * values[i] * 255.0
        result.append(UInt8(max(0.0, min(255.0, f.rounded()))))
    }
    let alpha = 255.0 - (255.0 - CGFloat(pixel[3])) * (1.0 - t)
    result.append(UInt8(max(0.0, min(255.0, alpha.rounded()))))
    return result
}

private let staticGlassTintRimProfile: [CGFloat] = [0.42, 0.30, 0.20, 0.07, 0.06, 0.05, 0.04, 0.035, 0.03, 0.02, 0.015, 0.01]

/// The rim of tinted glass, measured on iOS 27 captures (blue, red and green, light and dark): the tint lightens toward
/// the edge, by this factor at `distance` pixels (at 3x) inside it.
public func staticGlassTintRimGain(distance: CGFloat) -> CGFloat {
    let profile = staticGlassTintRimProfile
    if distance < 0.0 {
        return profile[0]
    }
    let index = Int(distance)
    if index >= profile.count - 1 {
        return 0.0
    }
    let fraction = distance - CGFloat(index)
    return profile[index] * (1.0 - fraction) + profile[index + 1] * fraction
}

/// How far, in points, a tint reaches past the shape: light tinted glass draws its tint 2px (at 3x) beyond the frame.
public func staticGlassTintOutset(isDark: Bool) -> CGFloat {
    return isDark ? 0.0 : 2.0 / 3.0
}

/// Signed distance (positive inside) from a point to a capsule's outline: a rounded rectangle whose radius is half its
/// shorter side.
public func staticGlassCapsuleDistance(_ point: CGPoint, frame: CGRect) -> CGFloat {
    return staticGlassCapsuleDistanceAndNormal(point, frame: frame).distance
}

/// The distance, and the vertical part of the outline's normal there: tinted glass lightens its top and bottom edges and
/// hardly its ends.
public func staticGlassCapsuleDistanceAndNormal(_ point: CGPoint, frame: CGRect) -> (distance: CGFloat, normalY: CGFloat) {
    let radius = min(frame.width, frame.height) * 0.5
    let cx = min(max(point.x, frame.minX + radius), frame.maxX - radius)
    let cy = min(max(point.y, frame.minY + radius), frame.maxY - radius)
    let dx = point.x - cx
    let dy = point.y - cy
    let length = (dx * dx + dy * dy).squareRoot()
    return (radius - length, length > 0.0 ? abs(dy) / length : 0.0)
}

/// A decoded asset (`Tools/make_static_glass.py` describes the format).
public struct StaticGlassAssetData {
    public let width: Int
    public let height: Int
    public let scale: Int
    /// The shape's frame inside the image, in pixels.
    public let frame: CGRect
    /// In pixels.
    public let capInsets: UIEdgeInsets
    /// Premultiplied RGBA, kept as stored: dark glass lightens the page, so its colour exceeds its alpha.
    public let pixels: Data

    public init?(data: Data) {
        let headerLength = 4 + 2 + 2 + 1 + 8 + 8
        guard data.count > headerLength, data.prefix(4) == Data("SGL1".utf8) else {
            return nil
        }
        let bytes = [UInt8](data.prefix(headerLength))
        func u16(_ offset: Int) -> Int {
            return Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
        }
        self.width = u16(4)
        self.height = u16(6)
        self.scale = Int(bytes[8])
        self.frame = CGRect(x: u16(9), y: u16(11), width: u16(13), height: u16(15))
        self.capInsets = UIEdgeInsets(top: CGFloat(u16(19)), left: CGFloat(u16(17)), bottom: CGFloat(u16(23)), right: CGFloat(u16(21)))
        guard let pixels = try? (data.subdata(in: headerLength ..< data.count) as NSData).decompressed(using: .zlib) as Data, pixels.count == self.width * self.height * 4 else {
            return nil
        }
        self.pixels = pixels
    }
}
