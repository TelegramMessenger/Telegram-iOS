import Foundation
import UIKit
import Display

/// The column's outer edge from the screen edge on the strip's side, as the vertical tab bar's.
private let outerMargin: CGFloat = 22.0
/// The gap between the column and a corner block above or below the strip.
private let clearance: CGFloat = 8.0
/// The column's end above the bottom edge when nothing is below it.
private let bottomMargin: CGFloat = 22.0

/// The column's width: the back circle's diameter and the capsule's thickness.
public let sideColumnWidth: CGFloat = 48.0
/// The capsule's length per item.
public let sideColumnItemPitch: CGFloat = 44.0
/// Between the back circle and the capsule, and between the column and the tab bar below it.
public let sideColumnSpacing: CGFloat = 12.0

/// Where the side column may go in a side strip (iPhone Duo).
public struct SideColumnRegion: Equatable {
    public var edge: ContainerViewLayoutSideEdge
    /// In the layout's coordinates: `sideColumnWidth` wide, from the column's top to the
    /// lowest point it may reach.
    public var frame: CGRect

    public init(edge: ContainerViewLayoutSideEdge, frame: CGRect) {
        self.edge = edge
        self.frame = frame
    }
}

/// The region in the right strip if there is one, else the left: from 8pt below a block above the
/// strip (never above `minY`) to 12pt above `reservedBelow` (the vertical tab bar), else 8pt above a
/// block below the strip, else 22pt above the bottom edge. Nil without a strip, when the strip is
/// narrower than 22 + 48pt, or when less than 48pt is left.
public func sideColumnRegion(layout: ContainerViewLayout, minY: CGFloat, reservedBelow: CGRect?) -> SideColumnRegion? {
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
    if strip.width < outerMargin + sideColumnWidth {
        return nil
    }
    let hasBlockAbove = strip.minY > 0.5
    let hasBlockBelow = strip.maxY < layout.size.height - 0.5
    let top = max(hasBlockAbove ? strip.minY + clearance : strip.minY, minY)
    let limit: CGFloat
    if let reservedBelow {
        limit = reservedBelow.minY - sideColumnSpacing
    } else if hasBlockBelow {
        limit = strip.maxY - clearance
    } else {
        limit = layout.size.height - bottomMargin
    }
    if limit - top < sideColumnWidth {
        return nil
    }
    let x: CGFloat
    switch edge {
    case .left:
        x = outerMargin
    case .right:
        x = layout.size.width - outerMargin - sideColumnWidth
    }
    return SideColumnRegion(edge: edge, frame: CGRect(x: x, y: top, width: sideColumnWidth, height: limit - top))
}

/// The column laid out in a region: an optional back circle, then a capsule of cells, then an optional
/// trailing circle.
public struct SideColumnItemsLayout: Equatable {
    /// In the region's coordinates.
    public var backFrame: CGRect?
    /// In the region's coordinates; nil without items.
    public var capsuleFrame: CGRect?
    /// In the capsule's coordinates: the visible items, then the ellipsis when items overflow.
    public var cellFrames: [CGRect]
    /// Indices into the items, in their original order.
    public var visibleItems: [Int]
    /// Indices into the items, in their original order: the ellipsis menu's items.
    public var overflowItems: [Int]
    /// In the region's coordinates: the trailing circle (the accent checkmark), when asked for.
    public var trailingFrame: CGRect?

    public init(backFrame: CGRect?, capsuleFrame: CGRect?, cellFrames: [CGRect], visibleItems: [Int], overflowItems: [Int], trailingFrame: CGRect? = nil) {
        self.backFrame = backFrame
        self.capsuleFrame = capsuleFrame
        self.cellFrames = cellFrames
        self.visibleItems = visibleItems
        self.overflowItems = overflowItems
        self.trailingFrame = trailingFrame
    }
}

/// Lays the column out in a region `regionLength` long: an optional back circle, a capsule of cells, and an
/// optional trailing circle below them, `sideColumnSpacing` apart. `priorities[i]` nil: item i never
/// overflows; otherwise higher overflows later and ties keep the original order. The trailing circle never
/// overflows: the capsule is laid out in the room above it. Nil when the column cannot hold what must stay
/// (the caller keeps the buttons in the header row).
public func sideColumnItemsLayout(regionLength: CGFloat, hasBack: Bool, priorities: [Int?], hasTrailingCircle: Bool = false) -> SideColumnItemsLayout? {
    let width = sideColumnWidth
    let pitch = sideColumnItemPitch
    var backFrame: CGRect?
    var capsuleTop: CGFloat = 0.0
    if hasBack {
        backFrame = CGRect(x: 0.0, y: 0.0, width: width, height: width)
        capsuleTop = width + sideColumnSpacing
    }
    let trailingRoom: CGFloat = hasTrailingCircle ? sideColumnSpacing + width : 0.0

    var capsuleFrame: CGRect?
    var cellFrames: [CGRect] = []
    var visibleItems: [Int] = []
    var overflowItems: [Int] = []
    let count = priorities.count
    if count != 0 {
        let room = regionLength - capsuleTop - trailingRoom
        let slots: Int = room < width ? 0 : max(1, Int(floor(room / pitch)))
        if slots == 0 {
            return nil
        }
        if count <= slots {
            visibleItems = Array(0 ..< count)
        } else {
            let keep = slots - 1
            let mustKeep = (0 ..< count).filter { priorities[$0] == nil }
            if mustKeep.count > keep {
                return nil
            }
            let ranked = (0 ..< count).compactMap { index -> (index: Int, priority: Int)? in
                return priorities[index].flatMap { (index, $0) }
            }.sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.index < rhs.index
            }
            let kept = Set(mustKeep + ranked.prefix(keep - mustKeep.count).map(\.index))
            visibleItems = (0 ..< count).filter { kept.contains($0) }
            overflowItems = (0 ..< count).filter { !kept.contains($0) }
        }
        let cellCount = visibleItems.count + (overflowItems.isEmpty ? 0 : 1)
        let itemsLength = CGFloat(cellCount) * pitch
        let length = max(width, itemsLength)
        let offset = floor((length - itemsLength) / 2.0)
        cellFrames = (0 ..< cellCount).map { index in
            CGRect(x: 0.0, y: offset + CGFloat(index) * pitch, width: width, height: pitch)
        }
        capsuleFrame = CGRect(x: 0.0, y: capsuleTop, width: width, height: length)
    }

    var trailingFrame: CGRect?
    if hasTrailingCircle {
        let top: CGFloat
        if let capsuleFrame {
            top = capsuleFrame.maxY + sideColumnSpacing
        } else if let backFrame {
            top = backFrame.maxY + sideColumnSpacing
        } else {
            top = 0.0
        }
        trailingFrame = CGRect(x: 0.0, y: top, width: width, height: width)
    }

    guard let bottom = trailingFrame?.maxY ?? capsuleFrame?.maxY ?? backFrame?.maxY, bottom <= regionLength else {
        return nil
    }
    return SideColumnItemsLayout(backFrame: backFrame, capsuleFrame: capsuleFrame, cellFrames: cellFrames, visibleItems: visibleItems, overflowItems: overflowItems, trailingFrame: trailingFrame)
}

/// How the column's container changes between two regions.
public enum SideColumnPlacementChange: Equatable {
    /// No column before or after.
    case none
    /// A column where there was none (folding): lay out without animation, fade in.
    case appear
    /// No column any more (unfolding): fade out in place.
    case disappear
    /// The same edge and position: animate the frame.
    case animate
    /// A rotation or the strip switching sides: fade out in place, fade in at the new frame.
    case move
}

public func sideColumnPlacementChange(from previous: SideColumnRegion?, to current: SideColumnRegion?) -> SideColumnPlacementChange {
    switch (previous, current) {
    case (.none, .none):
        return .none
    case (.none, .some):
        return .appear
    case (.some, .none):
        return .disappear
    case let (.some(previous), .some(current)):
        if previous.edge != current.edge || previous.frame.minX != current.frame.minX {
            return .move
        }
        return .animate
    }
}

/// A horizontal band's side insets beside a side column: `sideInsets(forBandFrom:to:)`, except that on the
/// column's side the strip inset stays while the band reaches up to 8pt below the column (`column.maxY`, in
/// the layout's coordinates).
public func sideColumnBandInsets(layout: ContainerViewLayout, bandMinY: CGFloat, bandMaxY: CGFloat, column: (edge: ContainerViewLayoutSideEdge, maxY: CGFloat)?) -> (left: CGFloat, right: CGFloat) {
    var insets = layout.sideInsets(forBandFrom: bandMinY, to: bandMaxY)
    if let column, bandMinY < column.maxY + clearance {
        switch column.edge {
        case .left:
            insets.left = max(insets.left, layout.safeInsets.left)
        case .right:
            insets.right = max(insets.right, layout.safeInsets.right)
        }
    }
    return insets
}

/// The region for a pushed screen that hosts its own chat-list-style header (`ChatListNavigationBar`): the strip
/// below the status corner, with no tab bar below it. Nil without a layout, in a form sheet, or without a strip, so
/// the header keeps its buttons in the row.
public func pushedScreenSideColumnRegion(layout: ContainerViewLayout?) -> SideColumnRegion? {
    guard let layout, !layout.presentedInFormSheet else {
        return nil
    }
    return sideColumnRegion(layout: layout, minY: (layout.statusBarHeight ?? 0.0) + 8.0, reservedBelow: nil)
}
