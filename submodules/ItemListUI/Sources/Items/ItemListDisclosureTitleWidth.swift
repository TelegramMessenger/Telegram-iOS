import Foundation
import CoreGraphics

/// The narrower width to lay a disclosure row's title out again in so that its trailing value (label) is not truncated,
/// or nil when the title keeps the layout it got at its full width.
///
/// `titleWidth` is the title laid out at its full width, `labelWidth` the value's untruncated width (0 when there is
/// none). The value sits in what `labelSharedWidth` leaves after the title; `titleSharedWidth` is the same room less
/// whatever follows the title on its line (a title badge). When the two already fit nothing changes. Otherwise a value
/// that needs at most two thirds of the room (a size, a count, a short setting) keeps its full width and the title gets
/// the rest, truncating or wrapping as the row lays it out, so a long localized title cannot squeeze the value into an
/// ellipsis even at the largest text sizes on a narrow screen. A longer value is long by design and keeps the old split:
/// the title first, the value truncates.
func itemListDisclosureNarrowedTitleWidth(titleWidth: CGFloat, labelWidth: CGFloat, labelSharedWidth: CGFloat, titleSharedWidth: CGFloat) -> CGFloat? {
    if labelWidth <= 0.0 {
        return nil
    }
    if labelSharedWidth - titleWidth >= labelWidth {
        return nil
    }
    if labelWidth > titleSharedWidth * 2.0 / 3.0 {
        return nil
    }
    return floor(titleSharedWidth - labelWidth)
}
