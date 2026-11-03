import CoreGraphics

/// UIScrollView content-offset bounds and pixel rounding. See analysis doc §6.
enum OffsetMath {
    /// Snap to the `1/scale` pixel grid (round-half-to-even), matching `_roundedProposedContentOffset:`.
    static func pixelRound(_ x: CGFloat, scale: CGFloat) -> CGFloat {
        guard abs(scale) >= .ulpOfOne else { return x }
        if scale == 1 { return x.rounded(.toNearestOrEven) }
        let f = x.rounded(.down)
        return f + ((x - f) * scale).rounded(.toNearestOrEven) / scale
    }

    /// `_minimumContentOffset` per axis: (baseOrigin − leading/top inset), pixel-rounded.
    static func minOffset(insetLeadingTop: CGFloat, baseOrigin: CGFloat = 0,
                          scale: CGFloat) -> CGFloat {
        pixelRound(baseOrigin - insetLeadingTop, scale: scale)
    }

    /// `_maximumContentOffsetForContentSize:` per axis: max(min, (content + trailing/bottom inset)ₚₓ − bounds).
    static func maxOffset(contentSize: CGFloat, insetTrailingBottom: CGFloat,
                          boundsSize: CGFloat, minOffset: CGFloat, scale: CGFloat) -> CGFloat {
        let raw = pixelRound(contentSize + insetTrailingBottom, scale: scale) - boundsSize
        return Swift.max(minOffset, raw)
    }
}
