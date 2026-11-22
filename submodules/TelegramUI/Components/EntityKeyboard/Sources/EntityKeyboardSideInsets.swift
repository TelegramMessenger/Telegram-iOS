import Foundation
import UIKit
import Display

// iPhone Duo: the keyboard spans the screen but its content keeps to the band between the side insets, which differ
// beside a side strip (folded portrait: left 0, right 84). With equal side insets both helpers reduce to the
// expressions they replace, so every other device lays out as before.

/// The x of content `width` wide centred on the band between `leftInset` and `rightInset` of `containerWidth`,
/// unrounded. With equal insets this is exactly `(containerWidth - width) / 2`.
func entityKeyboardBandCenteredX(width: CGFloat, containerWidth: CGFloat, leftInset: CGFloat, rightInset: CGFloat) -> CGFloat {
    return (containerWidth - width) / 2.0 + (leftInset - rightInset) / 2.0
}

/// The side insets of an emoji or sticker grid `gridWidth` wide, centred on the band. With equal insets both are
/// `floorToScreenPixels((width - gridWidth) / 2)`, as before.
func entityKeyboardGridSideInsets(width: CGFloat, gridWidth: CGFloat, leftInset: CGFloat, rightInset: CGFloat) -> (left: CGFloat, right: CGFloat) {
    let left = floorToScreenPixels(entityKeyboardBandCenteredX(width: gridWidth, containerWidth: width, leftInset: leftInset, rightInset: rightInset))
    return (left: left, right: left + (rightInset - leftInset))
}

/// The side strip on each side: how far one side inset exceeds the other. Content that scrolls sideways is clipped to
/// the band inside it and keeps the smaller inset as its own; zero on both sides when the insets are equal.
func entityKeyboardSideStrips(leftInset: CGFloat, rightInset: CGFloat) -> (left: CGFloat, right: CGFloat) {
    return (left: max(0.0, leftInset - rightInset), right: max(0.0, rightInset - leftInset))
}
