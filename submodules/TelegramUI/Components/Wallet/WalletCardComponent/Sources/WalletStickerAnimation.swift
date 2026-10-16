import UIKit
import Foundation

public final class WalletStickerSpring {
    public var value: CGFloat
    public var velocity: CGFloat = 0
    public var target: CGFloat
    public var stiffness: CGFloat
    public var damping: CGFloat

    public init(_ value: CGFloat, _ stiffness: CGFloat, _ damping: CGFloat) {
        self.value = value
        target = value
        self.stiffness = stiffness
        self.damping = damping
    }

    @discardableResult public func set(_ v: CGFloat) -> WalletStickerSpring { value = v; target = v; velocity = 0; return self }
    @discardableResult public func to(_ t: CGFloat) -> WalletStickerSpring { target = t; return self }
    @discardableResult public func with(_ k: CGFloat, _ z: CGFloat) -> WalletStickerSpring { stiffness = k; damping = z; return self }

    @discardableResult public func wrapTurns() -> WalletStickerSpring {
        let turns = (target / (2 * .pi)).rounded() * 2 * .pi
        value -= turns
        target -= turns
        return self
    }

    public func step(_ dt: CGFloat) {
        let c = 2 * damping * sqrt(stiffness)
        var left = dt
        while left > 0 {
            let h = min(left, 1 / 480)
            velocity += (-stiffness * (value - target) - c * velocity) * h
            value += velocity * h
            left -= h
        }
    }

    public func resting(_ eps: CGFloat = 0.002) -> Bool { abs(value - target) < eps && abs(velocity) < eps * 10 }
}

/// Timing from SendMoney 14: pattern flight uses elapsed time, not wave progress.
struct WalletCardStyleTransition {
    let progress: CGFloat
    let textMix: CGFloat
    let patternTime: CGFloat
    let contraction: CGFloat
    let removing: Bool

    init(fraction: Double, removing: Bool) {
        let x = CGFloat(min(1, max(0, fraction)))
        self.removing = removing
        if removing {
            let pull = x * x * (2.25 * x - 1.25)
            self.progress = max(0, pull)
            self.contraction = 1 - pull
        } else {
            self.progress = 1 - pow(1 - x, 4)
            self.contraction = 1
        }
        let text = min(1, max(0, (self.progress - 0.25) / 0.45))
        self.textMix = text * text * (3 - 2 * text)
        self.patternTime = removing ? 1 : min(1, x * 1.05 / 0.45)
    }

    func radius(origin: CGPoint, size: CGSize) -> CGFloat {
        let full = hypot(max(origin.x, size.width - origin.x), max(origin.y, size.height - origin.y)) * 1.05
        return full * (self.removing ? max(0, min(1, self.contraction)) : self.progress)
    }
}
