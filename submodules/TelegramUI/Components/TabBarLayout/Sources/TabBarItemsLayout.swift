import Foundation
import UIKit
import Display

/// The direction a tab bar lays its items out in.
public enum TabBarAxis: Equatable {
    case horizontal
    case vertical
}

/// An item's length along the bar in every mode but horizontal regular, and a regular item's size across it.
public let tabBarItemLength: CGFloat = 56.0
/// The gap between the bar's edge and its items, at both ends and on both sides.
public let tabBarInnerInset: CGFloat = 4.0
/// A compact (icon-only) item's size across the bar.
public let tabBarCompactItemThickness: CGFloat = 40.0
/// A horizontal compact bar that would hug its items within this much of its available length takes the
/// whole length instead: a small leftover gap on each side reads as a mistake rather than a design.
private let tabBarCompactFillThreshold: CGFloat = 60.0

public struct TabBarItemsLayout: Equatable {
    /// The bar: its items plus the inner inset on every side.
    public var size: CGSize
    /// Each item's frame in the bar's coordinates, in item order.
    public var itemFrames: [CGRect]

    public init(size: CGSize, itemFrames: [CGRect]) {
        self.size = size
        self.itemFrames = itemFrames
    }
}

/// The item frames and the bar's size, one item per entry of `unboundItemWidths`.
///
/// Horizontal regular items share `availableLength` (the bar's length available along the axis, inner
/// insets included): equal lengths when every item's unconstrained width fits, else lengths weighted by
/// those widths. Every other mode gives each item `tabBarItemLength` and the bar hugs its items, except
/// that a horizontal compact bar hugging them within `tabBarCompactFillThreshold` of `availableLength`
/// (or beyond it) takes `availableLength`, its items sharing it equally. The widths are unused outside
/// horizontal regular, and `availableLength` on the vertical axis.
public func tabBarItemsLayout(axis: TabBarAxis, isCompact: Bool, unboundItemWidths: [CGFloat], availableLength: CGFloat) -> TabBarItemsLayout {
    let count = unboundItemWidths.count
    let thickness = isCompact ? tabBarCompactItemThickness : tabBarItemLength

    let lengths: [CGFloat]
    if axis == .horizontal && !isCompact && count != 0 {
        let availableItemsLength = availableLength - tabBarInnerInset * 2.0
        let equalLength = floorToScreenPixels(availableItemsLength / CGFloat(count))
        if unboundItemWidths.allSatisfy({ $0 <= equalLength }) {
            lengths = Array(repeating: equalLength, count: count)
        } else {
            let weight = availableItemsLength / unboundItemWidths.reduce(0.0, +)
            lengths = unboundItemWidths.map { floorToScreenPixels($0 * weight) }
        }
    } else if axis == .horizontal && isCompact && count != 0 && availableLength - (CGFloat(count) * tabBarItemLength + tabBarInnerInset * 2.0) < tabBarCompactFillThreshold {
        let equalLength = floorToScreenPixels((availableLength - tabBarInnerInset * 2.0) / CGFloat(count))
        lengths = Array(repeating: equalLength, count: count)
    } else {
        lengths = Array(repeating: tabBarItemLength, count: count)
    }

    var itemFrames: [CGRect] = []
    var position = tabBarInnerInset
    for length in lengths {
        switch axis {
        case .horizontal:
            itemFrames.append(CGRect(x: position, y: tabBarInnerInset, width: length, height: thickness))
        case .vertical:
            itemFrames.append(CGRect(x: tabBarInnerInset, y: position, width: thickness, height: length))
        }
        position += length
    }
    let barLength = position + tabBarInnerInset
    let barThickness = thickness + tabBarInnerInset * 2.0
    switch axis {
    case .horizontal:
        return TabBarItemsLayout(size: CGSize(width: barLength, height: barThickness), itemFrames: itemFrames)
    case .vertical:
        return TabBarItemsLayout(size: CGSize(width: barThickness, height: barLength), itemFrames: itemFrames)
    }
}

/// The lens's selection rect in the bar's coordinates: the dragged position, else the selected item grown
/// by the inner inset along the axis, else the first item's place; always the bar's full thickness across
/// it, and clamped to the bar along it. A horizontal item narrower than its height is widened to 1.2 times
/// its height first.
public func tabBarLensSelectionFrame(axis: TabBarAxis, barSize: CGSize, selectedItemFrame: CGRect?, drag: (origin: CGFloat, itemLength: CGFloat)?) -> CGRect {
    var origin: CGFloat
    let length: CGFloat
    if let drag {
        origin = drag.origin
        length = drag.itemLength + tabBarInnerInset * 2.0
    } else if var itemFrame = selectedItemFrame {
        switch axis {
        case .horizontal:
            if itemFrame.width < itemFrame.height {
                itemFrame = itemFrame.insetBy(dx: floor((itemFrame.height * 1.2 - itemFrame.width) * -0.5), dy: 0.0)
            }
            origin = itemFrame.minX - tabBarInnerInset
            length = itemFrame.width + tabBarInnerInset * 2.0
        case .vertical:
            origin = itemFrame.minY - tabBarInnerInset
            length = itemFrame.height + tabBarInnerInset * 2.0
        }
    } else {
        origin = 0.0
        length = tabBarItemLength
    }

    switch axis {
    case .horizontal:
        origin = max(0.0, min(origin, barSize.width - length))
        return CGRect(x: origin, y: 0.0, width: length, height: barSize.height)
    case .vertical:
        origin = max(0.0, min(origin, barSize.height - length))
        return CGRect(x: 0.0, y: origin, width: barSize.width, height: length)
    }
}

/// The item under `point`, or the nearest one by distance along the axis when it is outside every item.
/// Nil when there are no items.
public func tabBarItemIndex(at point: CGPoint, axis: TabBarAxis, itemFrames: [CGRect]) -> Int? {
    var closest: (index: Int, distance: CGFloat)?
    for (index, frame) in itemFrames.enumerated() {
        if frame.contains(point) {
            return index
        }
        let distance: CGFloat
        switch axis {
        case .horizontal:
            distance = abs(point.x - frame.midX)
        case .vertical:
            distance = abs(point.y - frame.midY)
        }
        if let closestValue = closest {
            if distance < closestValue.distance {
                closest = (index, distance)
            }
        } else {
            closest = (index, distance)
        }
    }
    return closest?.index
}
