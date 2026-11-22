import UIKit
import WalletContext

/// Pure placement solver; all measurements are in the untransformed card's space.
struct WalletStickerPlacement {
    struct Spot { let center: CGPoint; let scale: CGFloat }
    let size: CGSize
    let obstacles: [CGRect]
    let occupants: [WalletContext.CardSticker]
    var side: CGFloat { size.width * WalletContext.CardSticker.widthFraction }
    static let minimum = CGFloat(WalletContext.CardSticker.minimumScale)
    static let maximum = CGFloat(WalletContext.CardSticker.maximumScale)

    func fits(_ center: CGPoint, scale: CGFloat) -> Bool {
        let edge = side * scale * 0.5
        guard CGRect(origin: .zero, size: size).insetBy(dx: edge, dy: edge).contains(center) else { return false }
        let r = side * scale * 0.36
        for rect in obstacles {
            let p = CGPoint(x: min(max(center.x, rect.minX), rect.maxX), y: min(max(center.y, rect.minY), rect.maxY))
            if hypot(p.x - center.x, p.y - center.y) < r { return false }
        }
        return !occupants.contains { s in
            hypot(CGFloat(s.x) * size.width - center.x, CGFloat(s.y) * size.height - center.y)
                < 0.29 * (side * scale + size.width * s.renderedWidthFraction)
        }
    }

    func nearest(_ near: CGPoint, scale: CGFloat, reach: CGFloat? = nil) -> CGPoint? {
        guard size.width > 0, size.height > 0 else { return nil }
        let edge = side * scale * 0.5
        let step = 4 * size.width / 361
        var best: CGPoint?
        var distance = CGFloat.greatestFiniteMagnitude
        var y = edge
        while y <= size.height - edge {
            var x = edge
            while x <= size.width - edge {
                let p = CGPoint(x: x, y: y), d = hypot(x - near.x, y - near.y)
                if d < distance, reach.map({ d <= $0 }) ?? true, fits(p, scale: scale) { best = p; distance = d }
                x += step
            }
            y += step
        }
        return best
    }

    func drop(near: CGPoint, scale: CGFloat) -> Spot? {
        let base = min(Self.maximum, max(Self.minimum, scale))
        var s = base
        while s >= Self.minimum - 0.001 {
            if let center = nearest(near, scale: s, reach: 26 * size.width / 361) { return Spot(center: center, scale: s) }
            s = max(Self.minimum, s - 0.06)
            if s == Self.minimum {
                if let center = nearest(near, scale: s, reach: 26 * size.width / 361) { return Spot(center: center, scale: s) }
                break
            }
        }
        return nearest(near, scale: base).map { Spot(center: $0, scale: base) }
    }

    func spread(aim: CGPoint?, scale: CGFloat) -> Spot? {
        guard size.width > 0, size.height > 0 else { return nil }
        let base = min(Self.maximum, max(Self.minimum, scale))
        let size = self.size
        let W = size.width, H = size.height, S = self.side
        let minScale = Self.minimum
        let obstacles = self.obstacles
        let others = self.occupants.map { s in (center: CGPoint(x: CGFloat(s.x) * size.width, y: CGFloat(s.y) * size.height), scale: CGFloat(s.renderedWidthFraction / WalletContext.CardSticker.widthFraction)) }
        func rnd() -> CGFloat { CGFloat.random(in: 0..<1) }
        let jitter: CGFloat = 10
        let sizeStep = 0.05 + 0.04 * rnd()
        let balanceX = W * (0.5 + 0.08 * (rnd() - 0.5))
        let balanceY = H * (0.55 + 0.08 * (rnd() - 0.5))
        var best = -CGFloat.greatestFiniteMagnitude
        var result: (CGPoint, CGFloat)?
        let margin = minScale * S * 0.5
        var y = margin
        while y <= H - margin {
            var x = margin
            while x <= W - margin {
                let edgeRoom = min(min(x, W - x), min(y, H - y))
                var sc = base * max(0.74, 1 - sizeStep * CGFloat(others.count))
                sc = min(sc, edgeRoom / (S * 0.5))
                var obstacleRoom = CGFloat.greatestFiniteMagnitude
                for o in obstacles {
                    obstacleRoom = min(obstacleRoom, hypot(min(max(x, o.minX), o.maxX) - x, min(max(y, o.minY), o.maxY) - y))
                }
                sc = min(sc, obstacleRoom / (S * 0.44))
                for g in others { sc = min(sc, hypot(g.center.x - x, g.center.y - y) / (S * 0.29) - g.scale) }
                let edgeGap = edgeRoom - S * 0.5 * sc
                sc *= 0.9 + 0.1 * min(1, max(0, edgeGap / 14))
                if sc >= minScale {
                    let room = min(edgeRoom, obstacleRoom)
                    var score: CGFloat
                    if others.isEmpty {
                        let hx = W * 0.6 + (aim.map { ($0.x - W * 0.6) * 0.2 } ?? 0)
                        let hy = H * 0.68 + (aim.map { ($0.y - H * 0.68) * 0.2 } ?? 0)
                        score = -0.45 * hypot(x - hx, y - hy) + 1.1 * sc * S + rnd() * jitter * 0.5
                    } else {
                        var gap = CGFloat.greatestFiniteMagnitude
                        for g in others { gap = min(gap, hypot(g.center.x - x, g.center.y - y) - S * 0.4 * (g.scale + sc)) }
                        let gapScore = gap < 0 ? gap * 2.5 : min(gap, S * 0.3)
                        var mx = x * sc * sc, my = y * sc * sc, mw = sc * sc
                        for g in others {
                            let w = g.scale * g.scale
                            mx += g.center.x * w; my += g.center.y * w; mw += w
                        }
                        let imbalance = hypot(mx / mw - balanceX, my / mw - balanceY)
                        var aligned: CGFloat = 0
                        for g in others {
                            aligned += max(0, 1 - abs(g.center.y - y) / (S * 0.12))
                            aligned += max(0, 1 - abs(g.center.x - x) / (S * 0.12))
                        }
                        score = 1.2 * gapScore + 0.9 * sc * S + 0.2 * min(room, S) - 0.35 * imbalance
                            - aligned * S * 0.08 - 0.04 * hypot(x - W * 0.5, y - H * 0.55) + rnd() * jitter
                        if let aim { score -= 0.04 * hypot(x - aim.x, y - aim.y) }
                    }
                    if score > best {
                        best = score
                        result = (CGPoint(x: x, y: y), sc)
                    }
                }
                x += 5 * size.width / 361
            }
            y += 5 * size.width / 361
        }
        return result.map { Spot(center: $0.0, scale: $0.1) }
    }

}
