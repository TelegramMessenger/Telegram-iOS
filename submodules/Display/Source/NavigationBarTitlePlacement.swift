import Foundation
import UIKit

// Navigation bar titles are centered in the band between the side safe insets (`leftInset` to
// `width - rightInset`) and kept clear of the buttons. iPhone Duo reserves a strip on one side only, so
// centering on the bar's full width put titles off the content's axis. With equal insets every result
// equals full-width centering. Title insets are measured from the bar's edges, buttons included.

/// The title insets after balancing a side without buttons: a right side without buttons keeps at least
/// 16pt; a left side without buttons mirrors the right buttons' margin beyond the right inset (not the
/// inset itself, which belongs to the right side only).
public func navigationBarTitleInsets(leftInset: CGFloat, rightInset: CGFloat, leftTitleInset: CGFloat, rightTitleInset: CGFloat) -> (left: CGFloat, right: CGFloat) {
    var left = leftTitleInset
    var right = rightTitleInset
    if (left == leftInset) != (right == rightInset) {
        if right == rightInset {
            right = max(rightInset, 16.0)
        } else if left == leftInset {
            left = leftInset + (right - rightInset)
        }
    }
    return (left, right)
}

/// A text title's x: centered in the band when it fits between margins equal to the larger button margin,
/// else centered between the buttons.
public func navigationBarTextTitleOriginX(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, leftTitleInset: CGFloat, rightTitleInset: CGFloat, titleWidth: CGFloat) -> CGFloat {
    let bandWidth = width - leftInset - rightInset
    let margin = max(leftTitleInset - leftInset, rightTitleInset - rightInset)
    if titleWidth <= bandWidth - margin * 2.0 {
        return floor(leftInset + (bandWidth - titleWidth) / 2.0)
    } else {
        return leftTitleInset + floor((width - leftTitleInset - rightTitleInset - titleWidth) / 2.0)
    }
}

/// A `NavigationBarTitleView`'s x: centered in the band, then moved clear of the right buttons, and
/// centered between the buttons when it would still cross the left ones.
public func navigationBarTitleViewOriginX(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, leftTitleInset: CGFloat, rightTitleInset: CGFloat, titleWidth: CGFloat) -> CGFloat {
    var x = floorToScreenPixels(leftInset + (width - leftInset - rightInset - titleWidth) * 0.5)
    if x + titleWidth > width - rightTitleInset {
        x = width - rightTitleInset - titleWidth
    }
    if x < leftTitleInset {
        x = leftTitleInset + floorToScreenPixels((width - leftTitleInset - rightTitleInset - titleWidth) * 0.5)
    }
    return x
}

/// The frame of a title view that fills the space it is given (one that cannot report its size): the band
/// with the larger button margin on both sides, so it stays symmetric about the band's center.
public func navigationBarFillingTitleFrame(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, leftTitleInset: CGFloat, rightTitleInset: CGFloat) -> (x: CGFloat, width: CGFloat) {
    let margin = max(leftTitleInset - leftInset, rightTitleInset - rightInset)
    let left = leftInset + margin
    let right = rightInset + margin
    let titleWidth = max(1.0, width - left - right)
    var x = floor(leftInset + (width - leftInset - rightInset - titleWidth) / 2.0)
    if x + titleWidth > width - right {
        x = width - right - titleWidth
    }
    if x < left {
        x = left + floorToScreenPixels((width - left - right - titleWidth) * 0.5)
    }
    return (x, titleWidth)
}
