import Foundation
import CoreGraphics

/// The Feed2 mockup's pull-to-refresh constants (Refresh.swift:86-91, 404-414, 514-516; FeedRow.swift RowShape), plus
/// two measured on it and one of ours (spec §1.4, §1.7).
public enum NewsRefreshMetrics {
    /// The pull at which the drop detaches and loading starts.
    public static let threshold: CGFloat = 76.0
    /// The glass container's merge spacing. Constant: changing it at the detach tore the neck in one frame.
    public static let pullSpacing: CGFloat = 18.0
    public static let dropSize: CGFloat = 44.0
    public static let dropMinSize: CGFloat = 10.0
    /// The sticker's box inside the drop.
    public static let iconSize: CGFloat = 28.0
    /// The sticker's "pop" (frames of the 60 fps file) and the pop's period while loading.
    public static let popFrames: Double = 34.0
    public static let stickerFramesPerSecond: Double = 60.0
    public static let loopDuration: Double = 0.9
    /// The list's hold while loading: the iOS 26 `UIRefreshControl` hold, measured on the mockup (y 182 vs 122).
    public static let holdInset: CGFloat = 60.0
    /// The hold's release, measured on the mockup: a smoothstep over 0.3 s.
    public static let releaseDuration: Double = 0.3
    public static let minLoading: Double = 1.2
    /// New posts slide in this long after the hold's release (or the finger's lift), once the list rests.
    public static let settleAfterRelease: Double = 0.38
    public static let insertFallback: Double = 0.9
    /// Ours: the drop shrinking back into the island, how every refresh ends.
    public static let retractDuration: Double = 0.3
    /// The block's card inside a row (`RowShape.inset`, `RowShape.corner`).
    public static let cardSideInset: CGFloat = 8.0
    public static let cardVerticalInset: CGFloat = 3.0
    public static let cardCorner: CGFloat = 20.0
}

/// The mockup's easing helpers (Geometry.swift:17-54, Refresh.swift:622-653). Every one clamps its input to 0...1.
public enum NewsRefreshCurves {
    public static func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        return a + (b - a) * t
    }

    public static func ramp(_ x: Double, _ a: Double, _ b: Double) -> CGFloat {
        return CGFloat(min(max((x - a) / (b - a), 0.0), 1.0))
    }

    public static func ramp(_ x: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
        return min(max((x - a) / (b - a), 0.0), 1.0)
    }

    public static func smooth(_ x: CGFloat) -> CGFloat {
        let u = min(max(x, 0.0), 1.0)
        return u * u * (3.0 - 2.0 * u)
    }

    public static func inOutCubic(_ x: CGFloat) -> CGFloat {
        let u = min(max(x, 0.0), 1.0)
        return u < 0.5 ? 4.0 * u * u * u : 1.0 - pow(-2.0 * u + 2.0, 3.0) / 2.0
    }

    public static func outQuad(_ x: CGFloat) -> CGFloat {
        let u = min(max(x, 0.0), 1.0)
        return 1.0 - (1.0 - u) * (1.0 - u)
    }

    public static func inQuad(_ x: CGFloat) -> CGFloat {
        let u = min(max(x, 0.0), 1.0)
        return u * u
    }

    /// The critically damped `.smooth(duration:)` (`DropMath.follow`): the lens-in's progress.
    public static func follow(_ t: Double, duration: Double) -> CGFloat {
        guard t > 0.0 else {
            return 0.0
        }
        let w = 2.0 * Double.pi / duration
        return CGFloat(1.0 - (1.0 + w * t) * exp(-w * t))
    }
}
