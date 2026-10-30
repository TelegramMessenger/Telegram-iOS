import Foundation
import CoreGraphics

/// The horizontal insets a reaction bar keeps from the screen edges. A bar lined up with its anchor's leading edge (a
/// lifted message's card, bubble-free mode) may come as close to the edges as the anchor itself; its right edge keeps
/// master's extra right inset (iPhone Duo's side strip). Everything else is master's.
public func reactionContextBarInsets(sideInset: CGFloat, rightSideInset: CGFloat, anchorMinX: CGFloat, alignsToAnchorLeadingEdge: Bool, forceTailToRight: Bool) -> (left: CGFloat, right: CGFloat) {
    if !alignsToAnchorLeadingEdge || forceTailToRight {
        return (sideInset, rightSideInset)
    }
    let leadingInset = min(sideInset, max(0.0, anchorMinX))
    return (leadingInset, min(rightSideInset, leadingInset + (rightSideInset - sideInset)))
}

/// Master's clamp of the bar's x between the insets: left, then right, then left again.
public func reactionContextClampedBarX(x: CGFloat, width: CGFloat, containerWidth: CGFloat, leftInset: CGFloat, rightInset: CGFloat) -> CGFloat {
    var x = max(leftInset, x)
    x = min(containerWidth - width - rightInset, x)
    if x + width > containerWidth - rightInset {
        x = containerWidth - rightInset - width
    }
    if x < leftInset {
        x = leftInset
    }
    return x
}

/// Where the tail of a bar lined up with a card hangs: beside the card, past its trailing edge, when the bar reaches that
/// far (the tail would otherwise cover the card's corner). Nil when it does not.
public func reactionContextTailBesideAnchor(anchorRect: CGRect, barMaxX: CGFloat, largeCircleSize: CGFloat) -> CGFloat? {
    let tail = anchorRect.maxX + 4.0 + largeCircleSize / 2.0
    if tail <= barMaxX - 46.0 / 2.0 {
        return tail
    }
    return nil
}

/// The width a bar lined up with a card has: from the card's left edge to a margin mirrored on the right.
public func reactionContextAvailableWidth(containerWidth: CGFloat, anchorMinX: CGFloat, sideInset: CGFloat, rightInset: CGFloat) -> CGFloat {
    let anchorX = max(0.0, anchorMinX)
    return containerWidth - anchorX - min(11.0 + sideInset, anchorX) - rightInset
}

/// The item size that keeps a bar's item count in the width it has; nil when the bar already fits.
public func reactionContextShrunkItemSize(visibleContentWidth: CGFloat, availableWidth: CGFloat, visibleItemCount: CGFloat, itemSpacing: CGFloat, sideInset: CGFloat) -> CGFloat? {
    guard visibleItemCount > 0.0, visibleContentWidth > availableWidth else {
        return nil
    }
    return floor((availableWidth - (visibleItemCount - 1.0) * itemSpacing - sideInset * 2.0) / visibleItemCount)
}
