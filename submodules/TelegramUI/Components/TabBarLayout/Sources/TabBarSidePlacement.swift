import Foundation
import UIKit
import Display

/// The bar's outer edge from the screen edge on the strip's side, as in the iPhone Duo mockup (under the clock).
private let tabBarSideOuterMargin: CGFloat = 22.0
/// The bar's end above the bottom edge when no corner block is below the strip.
private let tabBarSideBottomMargin: CGFloat = 22.0
/// The minimum gap between the bar and a corner block, or the strip's top.
private let tabBarSideClearance: CGFloat = 8.0

/// Where a vertical compact tab bar goes in a side strip (`ContainerViewLayout.sideStrip(edge:)`).
public struct TabBarSidePlacement: Equatable {
    public var edge: ContainerViewLayoutSideEdge
    /// The bar's frame in the layout's coordinates.
    public var frame: CGRect

    public init(edge: ContainerViewLayoutSideEdge, frame: CGRect) {
        self.edge = edge
        self.frame = frame
    }

    /// The frame with the bar hidden: fully past the screen edge on the strip's side.
    public func hiddenFrame(containerWidth: CGFloat) -> CGRect {
        var frame = self.frame
        switch self.edge {
        case .left:
            frame.origin.x = -frame.width
        case .right:
            frame.origin.x = containerWidth
        }
        return frame
    }
}

/// Where a vertical compact bar with `itemCount` items goes in `layout`: the right strip if there is one,
/// else the left; `tabBarSideOuterMargin` from the screen edge; bottom-anchored `tabBarSideBottomMargin`
/// above the bottom edge, or `tabBarSideClearance` above a corner block below the strip. Nil (the
/// horizontal bar) without a strip, when the strip is too narrow, or when the bar would start less than
/// `tabBarSideClearance` below the strip's top.
public func tabBarSidePlacement(layout: ContainerViewLayout, itemCount: Int) -> TabBarSidePlacement? {
    if itemCount <= 0 {
        return nil
    }
    let edge: ContainerViewLayoutSideEdge
    let strip: CGRect
    if let rightStrip = layout.sideStrip(edge: .right) {
        edge = .right
        strip = rightStrip
    } else if let leftStrip = layout.sideStrip(edge: .left) {
        edge = .left
        strip = leftStrip
    } else {
        return nil
    }

    let size = CGSize(width: tabBarCompactItemThickness + tabBarInnerInset * 2.0, height: CGFloat(itemCount) * tabBarItemLength + tabBarInnerInset * 2.0)
    if strip.width < tabBarSideOuterMargin + size.width {
        return nil
    }
    let hasBlockBelow = strip.maxY < layout.size.height - 0.5
    let maxY = hasBlockBelow ? strip.maxY - tabBarSideClearance : layout.size.height - tabBarSideBottomMargin
    let minY = maxY - size.height
    if minY < strip.minY + tabBarSideClearance {
        return nil
    }
    let x: CGFloat
    switch edge {
    case .left:
        x = tabBarSideOuterMargin
    case .right:
        x = layout.size.width - tabBarSideOuterMargin - size.width
    }
    return TabBarSidePlacement(edge: edge, frame: CGRect(x: x, y: minY, width: size.width, height: size.height))
}

/// The edit-mode toolbar's frame while the bar is in a side strip: `bottomInset` above the bottom edge,
/// inset from each side by the larger of `sideMargin` and that side's bottom-edge inset
/// (`bottomEdgeSideInsets()`), so it spans the strip and keeps clear only of a corner block at the bottom.
public func tabBarSideToolbarFrame(layout: ContainerViewLayout, sideMargin: CGFloat, bottomInset: CGFloat, height: CGFloat) -> CGRect {
    let bottomInsets = layout.bottomEdgeSideInsets()
    let left = max(sideMargin, bottomInsets.left)
    let right = max(sideMargin, bottomInsets.right)
    return CGRect(x: left, y: layout.size.height - bottomInset - height, width: layout.size.width - left - right, height: height)
}

/// Whether the bar shows icons without labels: always when it is vertical (`sidePlacement`), and in a
/// regular-width layout, where the tab bar sits in the master pane of a master-detail layout (iPad, and
/// iPhone Duo unfolded in landscape).
public func tabBarIsCompact(layout: ContainerViewLayout, sidePlacement: TabBarSidePlacement?) -> Bool {
    return sidePlacement != nil || layout.metrics.widthClass == .regular
}
