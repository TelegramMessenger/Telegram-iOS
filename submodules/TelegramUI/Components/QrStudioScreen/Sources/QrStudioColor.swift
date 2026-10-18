import Foundation
import CoreGraphics
struct QrStudioColor: Equatable {
    var r, g, b: CGFloat

    init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) {
        self.r = r; self.g = g; self.b = b
    }

    init(rgb: UInt32) {
        self.init(CGFloat((rgb >> 16) & 0xff) / 255, CGFloat((rgb >> 8) & 0xff) / 255, CGFloat(rgb & 0xff) / 255)
    }

    init(h: CGFloat, s: CGFloat, l: CGFloat) {
        guard s > 0 else {
            self.init(l, l, l)
            return
        }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        func channel(_ t0: CGFloat) -> CGFloat {
            var t = t0
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1 / 6 { return p + (q - p) * 6 * t }
            if t < 1 / 2 { return q }
            if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
            return p
        }
        self.init(channel(h + 1 / 3), channel(h), channel(h - 1 / 3))
    }

    static func mix(_ x: QrStudioColor, _ y: QrStudioColor, _ t: CGFloat) -> QrStudioColor {
        QrStudioColor(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t)
    }

    var hsl: (h: CGFloat, s: CGFloat, l: CGFloat) {
        let mx = max(r, g, b), mn = min(r, g, b)
        let l = (mx + mn) / 2
        guard mx > mn else { return (0, 0, l) }
        let d = mx - mn
        let s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        var h: CGFloat
        switch mx {
        case r: h = (g - b) / d + (g < b ? 6 : 0)
        case g: h = (b - r) / d + 2
        default: h = (r - g) / d + 4
        }
        return (h / 6, s, l)
    }

    var luminance: CGFloat {
        func linear(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    var ink: QrStudioColor {
        let (L0, a0, b0) = oklab
        let chroma = (a0 * a0 + b0 * b0).squareRoot()
        let hue = atan2(b0, a0)
        let relative = min(1, chroma / max(Self.maxChroma(L0, hue), 1e-6))
        let target = min(0.2, max(0.06, luminance))
        func at(_ L: CGFloat) -> QrStudioColor { QrStudioColor(lightness: L, chroma: relative * Self.maxChroma(L, hue), hue: hue) }
        var lo: CGFloat = 0.15, hi: CGFloat = max(L0, 0.3)
        for _ in 0..<26 {
            let mid = (lo + hi) / 2
            if at(mid).luminance > target { hi = mid } else { lo = mid }
        }
        return at((lo + hi) / 2)
    }

    var oklab: (CGFloat, CGFloat, CGFloat) {
        func linear(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let lr = linear(r), lg = linear(g), lb = linear(b)
        let l = cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
        let m = cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
        let s = cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
        return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    }

    private static func linearRGB(_ L: CGFloat, _ a: CGFloat, _ b: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        let l = pow(L + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(L - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(L - 0.0894841775 * a - 1.2914855480 * b, 3)
        return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    }

    init(oklab L: CGFloat, _ a: CGFloat, _ b: CGFloat) {
        func gamma(_ c: CGFloat) -> CGFloat {
            let x = min(max(c, 0), 1)
            return x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
        }
        let (lr, lg, lb) = Self.linearRGB(L, a, b)
        self.init(gamma(lr), gamma(lg), gamma(lb))
    }

    init(lightness L: CGFloat, chroma: CGFloat, hue: CGFloat) {
        self.init(oklab: L, chroma * cos(hue), chroma * sin(hue))
    }

    static func maxChroma(_ L: CGFloat, _ hue: CGFloat) -> CGFloat {
        var lo: CGFloat = 0, hi: CGFloat = 0.45
        for _ in 0..<20 {
            let mid = (lo + hi) / 2
            let (r, g, b) = linearRGB(L, mid * cos(hue), mid * sin(hue))
            let e: CGFloat = 1e-4
            if r >= -e, r <= 1 + e, g >= -e, g <= 1 + e, b >= -e, b <= 1 + e { lo = mid } else { hi = mid }
        }
        return lo
    }

    static func mixLab(_ x: QrStudioColor, _ y: QrStudioColor, _ t: CGFloat) -> QrStudioColor {
        let p = x.oklab, q = y.oklab
        return QrStudioColor(oklab: p.0 + (q.0 - p.0) * t, p.1 + (q.1 - p.1) * t, p.2 + (q.2 - p.2) * t)
    }

    static func ink(center: QrStudioColor, edge: QrStudioColor) -> QrStudioColor {
        mixLab(center, edge, 0.72).ink
    }

    var pastel: QrStudioColor {
        let (h, s, _) = hsl
        return QrStudioColor(h: h, s: min(s, 0.8), l: 0.8)
    }

    var rgb: UInt32 {
        func channel(_ v: CGFloat) -> UInt32 { UInt32((min(max(v, 0), 1) * 255).rounded()) }
        return (channel(self.r) << 16) | (channel(self.g) << 8) | channel(self.b)
    }
}

enum QrStudioPaletteId: Hashable {
    case color(Int32)
    case backdrop(Int32)
}

struct QrStudioPalette: Equatable {
    let id: QrStudioPaletteId?
    let name: String
    let colors: [QrStudioColor]
    let ink: QrStudioColor

    init(id: QrStudioPaletteId?, name: String, colors: [QrStudioColor], ink: QrStudioColor) {
        self.id = id
        self.name = name
        self.colors = colors
        self.ink = ink
    }

    static func profile(id: Int32, center: UInt32, edge: UInt32) -> QrStudioPalette {
        let center = QrStudioColor(rgb: center)
        let edge = QrStudioColor(rgb: edge)
        func mix(_ a: QrStudioColor, _ b: QrStudioColor, _ t: CGFloat) -> QrStudioColor {
            return QrStudioColor(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
        }
        let pattern = mix(edge, QrStudioColor(0.0, 0.0, 0.0), 0.45)
        let text = QrStudioColor(1.0, 1.0, 1.0)
        let glow = mix(center, text, 0.1)
        let corner = mix(center, edge, 0.85)
        let low = mix(edge, pattern, 0.12)
        return QrStudioPalette(id: .color(id), name: "profile-\(id)-\(center.rgb)-\(edge.rgb)", colors: [
            corner, mix(center, edge, 0.35), corner,
            mix(center, edge, 0.5), glow, mix(center, edge, 0.5),
            low, mix(center, edge, 0.62), low,
        ], ink: QrStudioColor.ink(center: center, edge: edge))
    }

    static func backdrop(id: Int32, center: UInt32, edge: UInt32, pattern: UInt32, text: UInt32) -> QrStudioPalette {
        let center = QrStudioColor(rgb: center)
        let edge = QrStudioColor(rgb: edge)
        let pattern = QrStudioColor(rgb: pattern)
        let text = QrStudioColor(rgb: text)
        let mix = QrStudioColor.mix
        let glow = mix(center, text, 0.1)
        let corner = mix(center, edge, 0.85)
        let low = mix(edge, pattern, 0.12)
        return QrStudioPalette(id: .backdrop(id), name: "backdrop-\(id)-\(center.rgb)-\(edge.rgb)", colors: [
            corner, mix(center, edge, 0.35), corner,
            mix(center, edge, 0.5), glow, mix(center, edge, 0.5),
            low, mix(center, edge, 0.62), low,
        ], ink: id == QrStudioPalette.blackBackdropId ? QrStudioColor(0.02, 0.02, 0.025) : QrStudioColor.ink(center: center, edge: edge))
    }

    static let blackBackdropId: Int32 = 0
    static let fallback: QrStudioPalette = QrStudioPalette.backdrop(id: QrStudioPalette.blackBackdropId, center: 0x363738, edge: 0x0e0f0f, pattern: 0x6c6868, text: 0x8c8f91)
}

func qrStudioSwatchPixels(colors: [QrStudioColor], side: Int) -> [UInt8] {
    guard colors.count == 9, side > 1 else {
        return []
    }
    var pixels = [UInt8](repeating: 0, count: side * side * 4)
    func node(_ c: Int, _ r: Int) -> QrStudioColor {
        return colors[min(max(r, 0), 2) * 3 + min(max(c, 0), 2)]
    }
    func smooth(_ x: CGFloat) -> CGFloat {
        return x * x * (3.0 - 2.0 * x)
    }
    let radius = CGFloat(side) / 2.0
    for y in 0 ..< side {
        for x in 0 ..< side {
            let dx = CGFloat(x) + 0.5 - radius
            let dy = CGFloat(y) + 0.5 - radius
            let distance = (dx * dx + dy * dy).squareRoot()
            let alpha = min(max(radius - distance, 0.0), 1.0)
            guard alpha > 0.0 else {
                continue
            }
            let u = CGFloat(x) / CGFloat(side - 1) * 2.0
            let v = CGFloat(y) / CGFloat(side - 1) * 2.0
            let c0 = min(Int(u), 1)
            let r0 = min(Int(v), 1)
            let fu = smooth(u - CGFloat(c0))
            let fv = smooth(v - CGFloat(r0))
            let p00 = node(c0, r0)
            let p10 = node(c0 + 1, r0)
            let p01 = node(c0, r0 + 1)
            let p11 = node(c0 + 1, r0 + 1)
            func mix(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
                let top = a + (b - a) * fu
                let bottom = c + (d - c) * fu
                return top + (bottom - top) * fv
            }
            let index = (y * side + x) * 4
            pixels[index] = UInt8(min(max(mix(p00.r, p10.r, p01.r, p11.r) * alpha * 255.0, 0.0), 255.0))
            pixels[index + 1] = UInt8(min(max(mix(p00.g, p10.g, p01.g, p11.g) * alpha * 255.0, 0.0), 255.0))
            pixels[index + 2] = UInt8(min(max(mix(p00.b, p10.b, p01.b, p11.b) * alpha * 255.0, 0.0), 255.0))
            pixels[index + 3] = UInt8(alpha * 255.0)
        }
    }
    return pixels
}

func qrStudioSwatchImage(colors: [QrStudioColor], side: Int) -> CGImage? {
    var pixels = qrStudioSwatchPixels(colors: colors, side: side)
    guard !pixels.isEmpty, let space = CGColorSpace(name: CGColorSpace.sRGB) else {
        return nil
    }
    return pixels.withUnsafeMutableBytes { buffer -> CGImage? in
        guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        return context.makeImage()
    }
}
