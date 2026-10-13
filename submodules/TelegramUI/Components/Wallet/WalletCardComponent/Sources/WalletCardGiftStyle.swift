import UIKit
import simd
import Display
import WalletContext

struct WalletOklch {
    var l: CGFloat
    var c: CGFloat
    var h: CGFloat

    init(l: CGFloat, c: CGFloat, h: CGFloat) {
        self.l = l
        self.c = c
        self.h = h
    }

    init(_ color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ v: CGFloat) -> CGFloat { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        let lr = lin(r), lg = lin(g), lb = lin(b)
        let l1 = cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
        let m1 = cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
        let s1 = cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
        let L = 0.2104542553 * l1 + 0.7936177850 * m1 - 0.0040720468 * s1
        let A = 1.9779984951 * l1 - 2.4285922050 * m1 + 0.4505937099 * s1
        let B = 0.0259040371 * l1 + 0.7827717662 * m1 - 0.8086757660 * s1
        self.init(l: L, c: hypot(A, B), h: atan2(B, A))
    }

    init(hex: UInt32) { self.init(UIColor(rgb: hex)) }

    private func linear(_ c: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        let a = c * cos(h), b = c * sin(h)
        let l1 = l + 0.3963377774 * a + 0.2158037573 * b
        let m1 = l - 0.1055613458 * a - 0.0638541728 * b
        let s1 = l - 0.0894841775 * a - 1.2914855480 * b
        let l3 = l1 * l1 * l1, m3 = m1 * m1 * m1, s3 = s1 * s1 * s1
        return (4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
                -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
                -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3)
    }

    var uiColor: UIColor {
        var cc = c
        var v = linear(cc)
        func outside(_ x: CGFloat) -> Bool { x < -0.001 || x > 1.001 }
        var tries = 0
        while outside(v.0) || outside(v.1) || outside(v.2), tries < 40 {
            cc *= 0.95
            v = linear(cc)
            tries += 1
        }
        func encode(_ x: CGFloat) -> CGFloat {
            let y = min(max(x, 0), 1)
            return y <= 0.0031308 ? 12.92 * y : 1.055 * pow(y, 1 / 2.4) - 0.055
        }
        return UIColor(red: encode(v.0), green: encode(v.1), blue: encode(v.2), alpha: 1)
    }
}


struct WalletCardTint: Equatable {
    let outerColor: UInt32
    let hue: CGFloat
    let chroma: CGFloat
    let cap: CGFloat
    let darkness: CGFloat
    let edgeL: CGFloat
    let centerL: CGFloat
    let darkC: CGFloat
    let lShift: CGFloat

    static let stockDark = WalletOklch(hex: 0x088FEE)
    static let stockLight = WalletOklch(hex: 0x16ABF9)
    static let stockAccent = WalletOklch(hex: 0x6DDCFF)
    static let stockAddress = WalletOklch(hex: 0x2A83E2)

    init(_ style: WalletContext.CardGiftStyle) {
        let b = (center: UInt32(bitPattern: style.innerColor), edge: UInt32(bitPattern: style.outerColor))
        let center = WalletOklch(hex: b.center), edge = WalletOklch(hex: b.edge)
        let mid = WalletOklch(Self.blend(b.center, b.edge, 0.5))
        outerColor = b.edge
        hue = mid.h
        let hueDeg = (mid.h * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        let violet = exp(-pow((hueDeg - 300) / 38, 2))
        chroma = min(max(mid.c * 1.5 / 0.155, 0.15), 1) * (1 + 0.18 * violet)
        lShift = -0.025 * violet
        darkness = min(max((0.6 - (center.l + edge.l) / 2) / 0.15, 0), 1)
        cap = center.c * 1.2
        darkC = center.c * 1.1
        edgeL = edge.l
        centerL = center.l
    }

    private static func blend(_ a: UInt32, _ b: UInt32, _ t: CGFloat) -> UIColor {
        func ch(_ v: UInt32, _ s: UInt32) -> CGFloat { CGFloat((v >> s) & 0xFF) / 255 }
        return UIColor(red: ch(a, 16) + (ch(b, 16) - ch(a, 16)) * t, green: ch(a, 8) + (ch(b, 8) - ch(a, 8)) * t,
                       blue: ch(a, 0) + (ch(b, 0) - ch(a, 0)) * t, alpha: 1)
    }

    func tint(_ ref: WalletOklch) -> WalletOklch {
        let dl = Self.stockDark.l, ll = Self.stockLight.l
        let pos = min(max((ref.l - dl) / (ll - dl), -2), 3)
        let own = edgeL - 0.02 + pos * (centerL - edgeL)
        let l = ref.l + (own - ref.l) * darkness + lShift
        let c = min(ref.c * chroma, cap * ref.c / 0.173) * (1 - darkness) + darkC * darkness
        return WalletOklch(l: min(max(l, 0.05), 0.97), c: c, h: hue)
    }

    var surface: WalletOklch { WalletOklch(tint(Self.stockDark).uiColor) }

    var accent: UIColor {
        let o = tint(Self.stockAccent)
        return o.l >= 0.8 ? o.uiColor : WalletOklch(l: 0.8, c: o.c, h: o.h).uiColor
    }

    var address: UIColor {
        let s = surface.l
        if s < 0.5 {
            let a = WalletOklch(accent)
            return WalletOklch(l: a.l * 0.8, c: a.c, h: a.h).uiColor
        }
        return WalletOklch(l: s - 0.115, c: Self.stockAddress.c * chroma * 1.1, h: hue).uiColor
    }

    var darkCard: Bool { WalletOklch(hex: outerColor).l < 0.2 }

    var patternColor: UIColor {
        let s = surface
        return darkCard ? .white : WalletOklch(l: s.l * 0.7, c: s.c * 1.4, h: s.h).uiColor
    }
    var glintColor: UIColor {
        let s = surface
        return darkCard ? .white : WalletOklch(l: s.l * 0.86, c: s.c * 1.6, h: s.h).uiColor
    }
    var patternOpacity: CGFloat { darkCard ? 0.32 : 1 }

    var uniforms: (SIMD4<Float>, SIMD4<Float>) {
        (SIMD4(Float(hue), Float(chroma), Float(cap), Float(darkness)),
         SIMD4(Float(edgeL), Float(centerL), Float(darkC), Float(lShift)))
    }
}


struct WalletCardStyleUniforms {
    var from0 = SIMD4<Float>.zero
    var from1 = SIMD4<Float>.zero
    var to0 = SIMD4<Float>.zero
    var to1 = SIMD4<Float>.zero
    var wave = SIMD4<Float>.zero
    var mode = SIMD4<Float>(0, 0, 1, Float(WalletCardTint.stockDark.l))
    var stock = SIMD4<Float>(Float(WalletCardTint.stockLight.l), 0, 0, 0)
    init(from: WalletContext.CardGiftStyle? = nil, to: WalletContext.CardGiftStyle? = nil,
         origin: CGPoint = .zero, radius: CGFloat = 0, progress: CGFloat = 1, fade: Bool = true) {
        if let from { (from0, from1) = WalletCardTint(from).uniforms; mode.x = 1 }
        if let to { (to0, to1) = WalletCardTint(to).uniforms; mode.y = 1 }
        mode.z = fade ? Float(progress) : -1
        wave = SIMD4(Float(origin.x), Float(origin.y), Float(radius), 0)
    }
}

struct WalletPatternRng {
    private var seed: Float

    private static func taus(_ z: UInt32, _ s1: UInt32, _ s2: UInt32, _ s3: UInt32, _ m: UInt32) -> UInt32 {
        let b = ((z << s1) ^ z) >> s2
        return ((z & m) << s3) ^ b
    }

    private static func mix(_ s: UInt32) -> UInt32 {
        let z1 = taus(s, 13, 19, 12, 429496729), z2 = taus(s, 2, 25, 4, 4294967288)
        let z3 = taus(s, 3, 11, 17, 429496280), z4 = 1664525 &* s &+ 1013904223
        return z1 ^ z2 ^ z3 ^ z4
    }

    init(seed0: UInt32, seed1: UInt32, seed2: UInt32) {
        let r1 = Self.mix(seed0 &* 1099087573) ^ (seed1 &* 1099087573)
        let r2 = Self.mix(r1) ^ (seed2 &* 1099087573)
        seed = Float(Self.mix(r2)) * Float(2.3283064365387e-10)
    }

    mutating func next() -> Float {
        let hashed = UInt32(seed * Float(1099087573 as UInt32))
        let old = seed
        seed = Float(Self.mix(hashed)) * Float(2.3283064365387e-10)
        return old
    }
}


enum WalletGiftPattern {
    struct Item {
        var center: CGPoint
        var size: CGFloat
    }

    static func items(center: CGPoint, width: CGFloat, avatar: CGFloat = 100) -> [Item] {
        var baseDistance = avatar / 2 + 22, rowDistance: CGFloat = 28, itemSize: CGFloat = 26
        if width <= 60 {
            baseDistance *= 0.35; rowDistance *= 0.3; itemSize *= 0.4
        } else if width < 150 {
            baseDistance *= 0.6; rowDistance *= 0.6; itemSize *= 0.83
        }
        var rng = WalletPatternRng(seed0: 123, seed1: 0, seed2: 0)
        var list: [Item] = []
        let span = CGFloat.pi * 2 / 6
        for row in 0..<5 {
            for i in 0..<6 {
                let distance = baseDistance + CGFloat(row) * rowDistance
                var angle = -CGFloat.pi / 2 + CGFloat(i) * span
                if row % 2 != 0 { angle += span / 2 }
                let scale = 0.7 + CGFloat(rng.next()) * 0.3
                list.append(Item(center: CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance),
                                 size: floor(itemSize * scale)))
            }
        }
        return list
    }

    static func alpha(at p: CGPoint, center: CGPoint, height: CGFloat) -> CGFloat {
        let dx = (p.x - center.x) / 190, dy = (p.y - center.y) / max(height / 2, 1)
        return 0.6 * 0.8 * max(0, 1 - sqrt(dx * dx + dy * dy))
    }

    static func draw(_ symbol: UIImage, color: UIColor, center: CGPoint, width: CGFloat, height: CGFloat,
                     in ctx: CGContext) {
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        for item in items(center: center, width: width) {
            symbol.draw(in: CGRect(x: item.center.x - item.size / 2, y: item.center.y - item.size / 2,
                                   width: item.size, height: item.size))
        }
        ctx.setBlendMode(.sourceIn)
        let colors = [color.withAlphaComponent(0.6 * 0.8).cgColor, color.withAlphaComponent(0).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) {
            ctx.saveGState()
            ctx.translateBy(x: center.x, y: center.y)
            ctx.scaleBy(x: 1, y: max(height / 2, 1) / 190)
            ctx.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 190,
                                   options: [.drawsAfterEndLocation])
            ctx.restoreGState()
        }
        ctx.endTransparencyLayer()
    }
}
