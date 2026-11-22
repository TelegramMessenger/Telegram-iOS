import Foundation
import UIKit
import Display

/// A horizontal compact bar's thickness: an item plus the inner inset on both sides. Its search button is as tall.
public let tabBarCompactBarThickness: CGFloat = tabBarCompactItemThickness + tabBarInnerInset * 2.0

/// How far above the bottom edge a bar outside the system layout floats, for a bottom inset of `bottomInset` (the
/// safe area's, or the keyboard's plus spacing): at least 8pt.
public func tabBarFloatingBottomInset(bottomInset: CGFloat) -> CGFloat {
    return max(bottomInset, 8.0)
}

/// How much to add to a detail pane's bottom inset for a row of bottom controls `rowHeight` tall, placed
/// `rowSpacing` above that inset, to be centred on the master pane's horizontal compact tab bar (iPad's split
/// layout, no keyboard), both panes sharing `bottomInset`.
public func tabBarAlignedRowBottomInsetOffset(bottomInset: CGFloat, rowSpacing: CGFloat, rowHeight: CGFloat) -> CGFloat {
    let barCenterInset = tabBarFloatingBottomInset(bottomInset: bottomInset) + tabBarCompactBarThickness * 0.5
    let rowCenterInset = bottomInset + rowSpacing + rowHeight * 0.5
    return barCenterInset - rowCenterInset
}

/// Where the inactive search button starts along a horizontal bar whose items take `tabsLength` of
/// `availableLength`: 8pt after the items in a compact bar, which can hug its items (`tabBarItemsLayout`) and is
/// centred on its items and search together, and at the end of `availableLength` in the other modes, which fill it.
public func tabBarSearchButtonOrigin(tabsLength: CGFloat, availableLength: CGFloat, buttonLength: CGFloat, isCompact: Bool) -> CGFloat {
    if isCompact {
        return tabsLength + 8.0
    } else {
        return availableLength - buttonLength
    }
}
