import Foundation
import CoreGraphics

/// The width a disclosure row's title is laid out in, given the value (label) shown at the row's trailing edge.
///
/// `sharedWidth` is the room the title and the value share on one line; `labelWidth` is the value's measured width
/// (0 when there is none). A short value (at most half of that room, e.g. a size or a count) keeps its full width and the
/// title gets the rest, truncating or wrapping as the row lays it out, so a long localized title cannot squeeze the value
/// into an ellipsis. A longer value is long by design and keeps the old split: the title first, the value truncates.
func itemListDisclosureTitleConstrainedWidth(maxTitleWidth: CGFloat, sharedWidth: CGFloat, labelWidth: CGFloat) -> CGFloat {
    if labelWidth > 0.0 && labelWidth <= sharedWidth * 0.5 {
        return min(maxTitleWidth, floor(sharedWidth - labelWidth))
    }
    return maxTitleWidth
}
