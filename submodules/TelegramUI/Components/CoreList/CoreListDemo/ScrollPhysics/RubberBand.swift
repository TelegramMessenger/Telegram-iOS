import CoreGraphics

/// UIScrollView's overscroll ("rubber-band") offset. See analysis doc §1.
/// `range` is the visible bounds dimension; `c` is the rubber-band coefficient (0.55 default).
enum RubberBand {
    /// Rubber-band coefficient for DIRECT (touch) overscroll — UIScrollView's standard 0.55
    /// (validated to machine precision against captured `_rubberBandOffsetForOffset:` ground truth).
    static let touchCoefficient: CGFloat = 0.55
    /// Rubber-band coefficient for INDIRECT (trackpad / continuous indirect-scroll) overscroll —
    /// fit to exactly 0.715 from the same captured ground truth (min==median==max over 70 samples;
    /// trackpad overscroll is looser than touch). See `docs/plans/2026-05-25-trackpad-scroll-design.md`.
    static let trackpadCoefficient: CGFloat = 0.715

    static func offset(_ x: CGFloat, min lo: CGFloat, max hi0: CGFloat,
                       range: CGFloat, c: CGFloat = touchCoefficient) -> CGFloat {
        let hi = Swift.max(hi0, lo)                 // max forced ≥ min, per §1
        guard abs(range) >= .ulpOfOne else { return x }
        if x > hi {
            let d = x - hi
            return hi + range * (1 - 1 / (1 + c * d / range))
        } else if x < lo {
            let d = lo - x
            return lo - range * (1 - 1 / (1 + c * d / range))
        } else {
            return x
        }
    }

    /// The inverse of `offset(_:)`: given a BANDED position, the un-banded finger position that
    /// produces it under these edges. Closed form — solving `y = range·(1 − 1/(1 + c·d/range))` for
    /// `d` gives `d = range·y / (c·(range − y))`.
    ///
    /// It exists so an in-progress drag can be re-anchored when the EDGES move under it. A drag maps
    /// finger travel to content through this band, so moving an edge silently re-scales that mapping:
    /// the same finger position bands differently and the content jumps on the very next `drag()`.
    /// Measured on the chat's overscroll hold — 116pt past the old edge became 10pt past the new one,
    /// the band stopped resisting, and the content shot out 64.8pt one frame after the edge changed.
    ///
    /// `y` is clamped just inside `range`: the band asymptotes there (infinite finger travel), so a
    /// position at or beyond it has no finite pre-image, and only a corrupt offset could ask.
    static func inverse(_ banded: CGFloat, min lo: CGFloat, max hi0: CGFloat,
                        range: CGFloat, c: CGFloat = touchCoefficient) -> CGFloat {
        let hi = Swift.max(hi0, lo)
        guard abs(range) >= .ulpOfOne, abs(c) >= .ulpOfOne else { return banded }
        let limit = abs(range) * (1 - 1e-6)
        if banded > hi {
            let y = Swift.min(banded - hi, limit)
            return hi + range * y / (c * (range - y))
        } else if banded < lo {
            let y = Swift.min(lo - banded, limit)
            return lo - range * y / (c * (range - y))
        } else {
            return banded
        }
    }
}
