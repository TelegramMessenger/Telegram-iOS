import Foundation
import CoreGraphics

public extension NewsSpring {
    /// How far a spring released from rest has gone toward its target after `t` seconds: 0 → 1, past 1 while it bounces.
    /// Core Animation renders a damping ratio above 1 as critical (`allowsOverdamping` is off), so this does too.
    func progress(at t: Double) -> CGFloat {
        if t <= 0.0 {
            return 0.0
        }
        let omega = Double((self.stiffness / self.mass).squareRoot())
        let zeta = Double(self.dampingRatio)
        if zeta < 0.9999 {
            let omegaD = omega * (1.0 - zeta * zeta).squareRoot()
            let envelope = exp(-zeta * omega * t)
            return CGFloat(1.0 - envelope * (cos(omegaD * t) + (zeta * omega / omegaD) * sin(omegaD * t)))
        } else {
            return CGFloat(1.0 - exp(-omega * t) * (1.0 + omega * t))
        }
    }

    /// `Motion.morph` (`.spring(duration: 0.6, bounce: 0)`): the island's width.
    static let islandMorph = NewsSpring(duration: 0.6, bounce: 0.0)
    /// The island's extra lift (`BottomBar.press`): `.spring(response: 0.14, dampingFraction: 0.7)` going down and
    /// `.spring(response: 0.34, dampingFraction: 0.32)` on release. Response r and damping fraction ζ are duration r,
    /// bounce 1 − ζ.
    static let islandPressDown = NewsSpring(duration: 0.14, bounce: 0.3)
    static let islandPressUp = NewsSpring(duration: 0.34, bounce: 0.68)
    /// `Motion.content` (`.spring(duration: 0.4, bounce: 0.1)`): the title's mute badge.
    static let titleBadge = NewsSpring(duration: 0.4, bounce: 0.1)
}

/// The channel bar's island (spec §2; BottomBar.swift).
public enum NewsIslandMetrics {
    public static let height: CGFloat = 40.0
    public static let minWidth: CGFloat = 185.0
    public static let labelInset: CGFloat = 20.0
    /// The least room a side of the label keeps when the island narrows to fit between the side buttons.
    public static let minLabelInset: CGFloat = 16.0
    /// The gap kept to a side button.
    public static let sideSpacing: CGFloat = 8.0
    public static let paintInset: CGFloat = 3.0
    public static let pressScale: CGFloat = 1.07
    public static let fontSize: CGFloat = 15.0
    /// The plus and chevron symbols.
    public static let symbolSize: CGFloat = 13.0
    public static let bellBaselineOffset: CGFloat = -3.5
    /// The shine's tilt.
    public static let shineAngle: CGFloat = 22.0 * CGFloat.pi / 180.0
    public static let changeHapticIntensity: CGFloat = 0.8
    public static let settleHapticDelay: Double = 0.25
    public static let settleHapticIntensity: CGFloat = 0.45
}

/// The island's width: the mockup's 185, wider for a longer label, no wider than the room between the side buttons,
/// and never under its label plus `minLabelInset` a side.
public func newsIslandWidth(labelWidth: CGFloat, available: CGFloat) -> CGFloat {
    let M = NewsIslandMetrics.self
    let preferred = max(M.minWidth, labelWidth + 2.0 * M.labelInset)
    return max(min(preferred, available), labelWidth + 2.0 * M.minLabelInset)
}

/// The capsule in the island's bounds: centred on them, or centred between the side buttons when centring would cross
/// one.
public func newsIslandCapsuleFrame(boundsWidth: CGFloat, height: CGFloat, width: CGFloat, leftLimit: CGFloat, rightLimit: CGFloat) -> CGRect {
    var x = (boundsWidth - width) * 0.5
    if x < leftLimit || x + width > rightLimit {
        x = (leftLimit + rightLimit - width) * 0.5
    }
    return CGRect(x: x, y: 0.0, width: width, height: height)
}

/// The part of the capsule that takes touches: never past the side buttons' limits, so an island its label has made
/// wider than the room on a narrow screen does not take the side buttons' taps.
public func newsIslandHitFrame(capsuleFrame: CGRect, leftLimit: CGFloat, rightLimit: CGFloat) -> CGRect {
    let minX = max(capsuleFrame.minX, leftLimit)
    let maxX = min(capsuleFrame.maxX, rightLimit)
    return CGRect(x: minX, y: capsuleFrame.minY, width: max(0.0, maxX - minX), height: capsuleFrame.height)
}

/// The paint inside the island at one moment of a change (`Dye`): `fill` is the paint's opacity, `shine` the shine's
/// centre as a fraction of the paint's width, `shineAlpha` its strength. Going to paint the shine runs over the paint
/// coming in; going to glass it runs over the paint dissolving.
public struct NewsIslandDye: Equatable {
    public var fill: CGFloat
    public var shine: CGFloat
    public var shineAlpha: CGFloat

    public init(fill: CGFloat, shine: CGFloat, shineAlpha: CGFloat) {
        self.fill = fill
        self.shine = shine
        self.shineAlpha = shineAlpha
    }

    public static let duration: Double = 0.42

    /// The shine's two bands, along a normal tilted by `NewsIslandMetrics.shineAngle`: a wide soft halo and a narrow
    /// bright streak. Half-widths are fractions of the paint's width.
    public static let bands: [(halfWidth: CGFloat, peak: CGFloat)] = [(0.36, 0.35), (0.14, 0.95)]

    public static func still(paint: Bool) -> NewsIslandDye {
        return NewsIslandDye(fill: paint ? 1.0 : 0.0, shine: -1.0, shineAlpha: 0.0)
    }

    public static func at(_ t: Double, toPaint: Bool) -> NewsIslandDye {
        let C = NewsRefreshCurves.self
        let t = min(max(t, 0.0), duration)
        let fill = toPaint ? C.smooth(C.ramp(t, 0.02, 0.3)) : 1.0 - C.smooth(C.ramp(t, 0.06, 0.34))
        let sweep = C.smooth(C.ramp(t, 0.0, 0.32))
        let shineAlpha = CGFloat(pow(sin(Double.pi * min(1.0, t / 0.32)), 0.6))
        return NewsIslandDye(fill: fill, shine: -0.25 + 1.5 * sweep, shineAlpha: shineAlpha)
    }
}

/// One glyph of the island's label during a roll.
public struct NewsGlyphRoll: Equatable {
    public var dy: CGFloat
    public var alpha: CGFloat
    public var blur: CGFloat

    public init(dy: CGFloat, alpha: CGFloat, blur: CGFloat) {
        self.dy = dy
        self.alpha = alpha
        self.blur = blur
    }
}

/// The label roll (`LabelRoll`, `RollRenderer`): the old label's glyphs leave upward and the new one's arrive from
/// below with a small overshoot, in a wave from left to right; glyphs blur while they move.
public enum NewsLabelRoll {
    public static let duration: Double = 0.5
    /// How much of the run the last glyph lags the first.
    public static let stagger: CGFloat = 0.55
    public static let lift: CGFloat = 16.0
    public static let blur: CGFloat = 3.5

    /// `LabelRoll.ease`: the roll's progress after `u` of its duration.
    public static func progress(_ u: Double) -> CGFloat {
        let u = min(max(u, 0.0), 1.0)
        return CGFloat(1.0 - pow(1.0 - u, 2.2))
    }

    /// Glyph `index` of `count`'s own progress at roll progress `p`.
    public static func local(_ p: CGFloat, index: Int, count: Int) -> CGFloat {
        let f = count > 1 ? CGFloat(index) / CGFloat(count - 1) : 0.0
        return min(max(p * (1.0 + stagger) - stagger * f, 0.0), 1.0)
    }

    public static func outgoing(_ local: CGFloat) -> NewsGlyphRoll {
        return NewsGlyphRoll(dy: -lift * local * local, alpha: 1.0 - min(1.0, local * 1.4), blur: local * blur)
    }

    public static func incoming(_ local: CGFloat) -> NewsGlyphRoll {
        return NewsGlyphRoll(dy: lift * (1.0 - backOut(local)), alpha: min(1.0, local * 1.6), blur: (1.0 - local) * blur)
    }

    /// An ease-out past its end and back: the glyph snaps into place.
    static func backOut(_ x: CGFloat) -> CGFloat {
        let k: CGFloat = 1.7
        let t = x - 1.0
        return 1.0 + t * t * ((k + 1.0) * t + k)
    }
}
