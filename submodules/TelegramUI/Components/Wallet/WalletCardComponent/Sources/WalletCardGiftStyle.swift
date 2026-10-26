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
        return WalletOklch(l: s - 0.22, c: Self.stockAddress.c * chroma * 1.1, h: hue).uiColor
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

enum WalletGiftPattern {
    struct Item {
        var center: CGPoint
        var size: CGFloat
    }

    static let alpha: CGFloat = 0.18

    static func items(size: CGSize, maxX: CGFloat = .greatestFiniteMagnitude) -> [Item] {
        let k = size.width / 370
        let columnPitch = 84 * k, rowPitch = 25 * k, itemSize = floor(20 * k)
        guard rowPitch > 0 else { return [] }
        let center = CGPoint(x: size.width / 2 + 4 * k, y: size.height / 2)
        let rows = Int(ceil(size.height / 2 / rowPitch)) + 1
        let columns = Int(ceil(size.width / 2 / columnPitch)) + 1
        var list: [Item] = []
        for row in -rows...rows {
            let shift: CGFloat = row % 2 == 0 ? 0 : columnPitch / 2
            for column in -columns...columns {
                let point = CGPoint(x: center.x + CGFloat(column) * columnPitch + shift, y: center.y + CGFloat(row) * rowPitch)
                if point.x < -itemSize || point.x > min(size.width + itemSize, maxX) || point.y < -itemSize || point.y > size.height + itemSize {
                    continue
                }
                list.append(Item(center: point, size: itemSize))
            }
        }
        return list
    }

    static func draw(_ symbol: UIImage, color: UIColor, size: CGSize, in ctx: CGContext) {
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        for item in items(size: size) {
            symbol.draw(in: CGRect(x: item.center.x - item.size / 2, y: item.center.y - item.size / 2,
                                   width: item.size, height: item.size))
        }
        ctx.setBlendMode(.sourceIn)
        ctx.setFillColor(color.withAlphaComponent(alpha).cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.endTransparencyLayer()
    }
}
