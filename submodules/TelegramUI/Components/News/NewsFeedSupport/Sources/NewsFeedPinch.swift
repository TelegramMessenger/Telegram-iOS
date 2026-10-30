import Foundation
import CoreGraphics

/// A pinch on the feed switches Compact and Expanded, the "…" menu's choice: out expands, in compacts (a pinch toward
/// the mode on screen only gives). The whole feed follows the fingers down to `switchScale` (or up to its inverse):
/// there the rows morph, with a tap of haptics, and past it the feed only
/// gives a little more, as a scroll view past its end does. On release the feed springs back to 1.
public enum NewsFeedPinch {
    /// The feed's scale at which the mode switches: a pinch in to 0.8, or out to 1 / 0.8.
    public static let switchScale: CGFloat = 0.8
    /// How much further, as a fraction of the switch scale, the feed gives past the switch. Asymptotic: the fingers
    /// never reach it.
    public static let overshoot: CGFloat = 0.0625
    /// Once the mode switched, the pinch arms again when it comes back under this fraction of the switch, so a
    /// pinch held past the switch does not flicker between the modes.
    public static let rearmProgress: CGFloat = 0.5
}

/// The pinch's progress toward the switch, from the recognizer's scale (1 with the fingers where they landed):
/// 0 untouched, -1 at the switch in, +1 at the switch out, beyond ±1 past it. Symmetric in the ratio: a pinch in to
/// 0.8 and one out to 1.25 are the same distance.
public func newsFeedPinchProgress(ratio: CGFloat) -> CGFloat {
    guard ratio > 0.0, ratio.isFinite else {
        return 0.0
    }
    return log(ratio) / -log(NewsFeedPinch.switchScale)
}

/// The feed's scale at `progress`: exactly the fingers' ratio up to the switch (0.8 at -1, 1.25 at +1), then the
/// switch scale plus a rubber band of at most `overshoot` of it.
public func newsFeedPinchScale(progress: CGFloat) -> CGFloat {
    let magnitude = abs(progress)
    let sign: CGFloat = progress < 0.0 ? -1.0 : 1.0
    if magnitude <= 1.0 {
        return pow(NewsFeedPinch.switchScale, -progress)
    }
    let base = pow(NewsFeedPinch.switchScale, -sign)
    let give = NewsFeedPinch.overshoot * (1.0 - exp(-(magnitude - 1.0)))
    return base * (1.0 + sign * give)
}

/// Whether the pinch has switched the mode, and whether it may again. One switch per crossing of the switch
/// point; the pinch arms again only after it comes back toward its start (`rearmProgress`).
public struct NewsFeedPinchState {
    private var isArmed: Bool = true

    public init() {
    }

    /// Feeds the pinch's progress; true exactly when the mode switches now.
    public mutating func update(progress: CGFloat) -> Bool {
        let magnitude = abs(progress)
        if self.isArmed {
            if magnitude >= 1.0 {
                self.isArmed = false
                return true
            }
        } else if magnitude <= NewsFeedPinch.rearmProgress {
            self.isArmed = true
        }
        return false
    }
}
