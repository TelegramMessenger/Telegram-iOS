import CoreGraphics

/// UIScrollView's flick landing point. See analysis doc §5.
/// Analytic integral of the exponential decay from `velocity` (pts/ms) down to the 0.01 pts/ms floor.
enum Projection {
    static func target(offset: CGFloat, velocity: CGFloat, lnRate: CGFloat,
                       vScale: CGFloat = 1, floor: CGFloat = 0.01) -> CGFloat {
        guard abs(velocity) > floor else { return offset }
        guard abs(lnRate) > .ulpOfOne else { return offset }   // rate == 1 → no decay → no projection
        let signed = (abs(velocity) - floor) * (velocity >= 0 ? 1 : -1)
        return offset - signed / lnRate * vScale
    }
}
